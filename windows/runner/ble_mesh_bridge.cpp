// WinRT BLE bridge for Prepper Mesh — the Windows sibling of
// BleMeshBridge.kt (Android) and BleMeshBridge.swift (iOS/macOS).
//
// Same wire protocol:
//   MethodChannel  "prepper/ble_mesh"        start/stop/connect/disconnect/send
//   EventChannel   "prepper/ble_mesh/events" {type: peer|data|state, id, bytes}
//   GATT service   0000ffe0-… with write-char ffe1 (peers write to us) and
//                  notify-char ffe2 (we notify subscribed centrals).
//
// Threading model:
//   • Los handlers de método corren en el platform thread (STA). Todo el
//     trabajo WinRT bloqueante (CreateAsync/Connect/Write con .get()) se
//     despacha a un worker std::thread con apartment MTA propio — .get() en
//     un STA dispara WINRT_ASSERT y congelaría la ventana.
//   • El EventSink y los MethodResult solo se tocan en el platform thread:
//     los callbacks WinRT (threadpool) y los workers encolan eventos y
//     respuestas en colas protegidas por mutex, drenadas por un WM_TIMER del
//     hilo principal (SetTimer con HWND null genera su PROPIO id — hay que
//     guardar el retorno, compararlo en el TimerProc sería siempre falso con
//     el id pedido).
//   • Los delegados WinRT van completos en try/catch: una hresult_error que
//     escapa de un delegado en el threadpool termina el proceso entero.
#include "ble_mesh_bridge.h"

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.Streams.h>

#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#include <utility>
#include <vector>

using namespace winrt;
using namespace winrt::Windows::Devices::Bluetooth;
using namespace winrt::Windows::Devices::Bluetooth::Advertisement;
using namespace winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;
using namespace winrt::Windows::Storage::Streams;

namespace {

const guid kServiceUuid{0x0000ffe0, 0x0000, 0x1000,
                        {0x80, 0x00, 0x00, 0x80, 0x5f, 0x9b, 0x34, 0xfb}};
const guid kTxUuid{0x0000ffe1, 0x0000, 0x1000,
                   {0x80, 0x00, 0x00, 0x80, 0x5f, 0x9b, 0x34, 0xfb}};
const guid kRxUuid{0x0000ffe2, 0x0000, 0x1000,
                   {0x80, 0x00, 0x00, 0x80, 0x5f, 0x9b, 0x34, 0xfb}};

// Re-anunciar el mismo peer como mucho cada 2s: Dart deduplica y reintenta
// conexiones fallidas al siguiente aviso (igual que Android, que re-emite en
// cada scan result); sin re-emisión un connect fallido dejaba al peer
// inalcanzable para siempre.
constexpr ULONGLONG kPeerReemitMs = 2000;

std::string AddressToId(uint64_t addr) {
  std::ostringstream o;
  o << std::hex << addr;
  return o.str();
}

IBuffer ToBuffer(const std::vector<uint8_t>& bytes) {
  DataWriter w;
  w.WriteBytes(array_view<const uint8_t>(bytes.data(),
                                         bytes.data() + bytes.size()));
  return w.DetachBuffer();
}

std::vector<uint8_t> FromBuffer(const IBuffer& buf) {
  std::vector<uint8_t> out(buf.Length());
  if (!out.empty()) {
    DataReader r = DataReader::FromBuffer(buf);
    r.ReadBytes(array_view<uint8_t>(out.data(), out.data() + out.size()));
  }
  return out;
}

// One remote peer we connected to as CENTRAL.
struct Peer {
  BluetoothLEDevice device{nullptr};
  GattCharacteristic tx{nullptr};  // we write mesh chunks here (their ffe1)
  GattCharacteristic rx{nullptr};  // they notify us here (their ffe2)
  winrt::event_token rx_token{};
};

using MethodResultPtr =
    std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>;

class BleMeshBridge {
 public:
  explicit BleMeshBridge(flutter::BinaryMessenger* messenger) {
    method_channel_ =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "prepper/ble_mesh",
            &flutter::StandardMethodCodec::GetInstance());
    event_channel_ =
        std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
            messenger, "prepper/ble_mesh/events",
            &flutter::StandardMethodCodec::GetInstance());

    event_channel_->SetStreamHandler(
        std::make_unique<
            flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
            [this](const flutter::EncodableValue*,
                   std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                       events)
                -> std::unique_ptr<
                    flutter::StreamHandlerError<flutter::EncodableValue>> {
              std::lock_guard<std::mutex> lock(mutex_);
              sink_ = std::move(events);
              return nullptr;
            },
            [this](const flutter::EncodableValue*)
                -> std::unique_ptr<
                    flutter::StreamHandlerError<flutter::EncodableValue>> {
              std::lock_guard<std::mutex> lock(mutex_);
              sink_.reset();
              return nullptr;
            }));

    method_channel_->SetMethodCallHandler(
        [this](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                   result) {
          const std::string& m = call.method_name();
          MethodResultPtr shared(std::move(result));
          if (m == "start") {
            RunOnWorker([this, shared] { QueueReply(shared, Start()); });
          } else if (m == "stop") {
            RunOnWorker([this, shared] {
              Stop();
              QueueReply(shared, true);
            });
          } else if (m == "connect") {
            const std::string id = ArgId(call);
            RunOnWorker(
                [this, shared, id] { QueueReply(shared, Connect(id)); });
          } else if (m == "disconnect") {
            const std::string id = ArgId(call);
            RunOnWorker([this, shared, id] {
              Disconnect(id);
              QueueReply(shared, true);
            });
          } else if (m == "send") {
            const std::string id = ArgId(call);
            const std::vector<uint8_t> bytes = ArgBytes(call);
            RunOnWorker(
                [this, shared, id, bytes] { QueueReply(shared, Send(id, bytes)); });
          } else {
            shared->NotImplemented();
          }
        });

    // Timer del hilo principal que drena eventos y respuestas. OJO: con
    // HWND null, Windows IGNORA el id solicitado y devuelve uno nuevo — el
    // TimerProc debe comparar contra el RETORNO, no contra una constante.
    timer_id_ = SetTimer(nullptr, 0, 50, &BleMeshBridge::TimerProc);
    instance_ = this;
  }

 private:
  static BleMeshBridge* instance_;

  static void CALLBACK TimerProc(HWND, UINT, UINT_PTR id, DWORD) {
    BleMeshBridge* self = instance_;
    if (self && id == self->timer_id_) self->FlushPending();
  }

  // Ejecuta trabajo WinRT bloqueante fuera del platform thread. Un hilo por
  // llamada es suficiente: las operaciones BLE son esporádicas (conectar,
  // escribir chunks) y el orden por-peer lo garantiza el protocolo de Dart,
  // que espera cada invokeMethod antes del siguiente.
  static void RunOnWorker(std::function<void()> work) {
    std::thread([work = std::move(work)] {
      // Los hilos nuevos no tienen apartment COM; WinRT lo exige.
      try {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
      } catch (const hresult_error&) {
        // Ya inicializado con otro modo — seguir igual.
      }
      work();
    }).detach();
  }

  static std::string ArgId(
      const flutter::MethodCall<flutter::EncodableValue>& call) {
    if (const auto* map =
            std::get_if<flutter::EncodableMap>(call.arguments())) {
      auto it = map->find(flutter::EncodableValue("id"));
      if (it != map->end()) {
        if (const auto* s = std::get_if<std::string>(&it->second)) return *s;
      }
    }
    return "";
  }

  static std::vector<uint8_t> ArgBytes(
      const flutter::MethodCall<flutter::EncodableValue>& call) {
    if (const auto* map =
            std::get_if<flutter::EncodableMap>(call.arguments())) {
      auto it = map->find(flutter::EncodableValue("bytes"));
      if (it != map->end()) {
        if (const auto* v = std::get_if<std::vector<uint8_t>>(&it->second))
          return *v;
      }
    }
    return {};
  }

  // Encola un evento desde CUALQUIER hilo; el timer lo entrega en el
  // platform thread.
  void Emit(flutter::EncodableMap event) {
    std::lock_guard<std::mutex> lock(mutex_);
    pending_events_.push_back(std::move(event));
    // Backstop: si Dart nunca abre el EventChannel la cola no debe crecer
    // sin límite mientras llegan advertisements.
    while (pending_events_.size() > 512) pending_events_.pop_front();
  }

  void QueueReply(MethodResultPtr result, bool value) {
    std::lock_guard<std::mutex> lock(mutex_);
    pending_replies_.emplace_back(std::move(result), value);
  }

  void FlushPending() {
    std::deque<flutter::EncodableMap> events;
    std::deque<std::pair<MethodResultPtr, bool>> replies;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      replies.swap(pending_replies_);
      if (sink_) events.swap(pending_events_);
    }
    for (auto& [result, value] : replies) {
      result->Success(flutter::EncodableValue(value));
    }
    for (auto& e : events) {
      std::lock_guard<std::mutex> lock(mutex_);
      if (sink_) sink_->Success(flutter::EncodableValue(std::move(e)));
    }
  }

  void EmitState(const char* value) {
    Emit({{flutter::EncodableValue("type"), flutter::EncodableValue("state")},
          {flutter::EncodableValue("value"),
           flutter::EncodableValue(value)}});
  }

  bool Start() {
    try {
      StartPeripheral();
      StartWatcher();
      EmitState("on");
      return true;
    } catch (const hresult_error&) {
      // No BLE stack / radio off. Distinguishing would need Radio APIs with
      // extra capabilities; "unsupported" keeps the transport degraded and
      // the LAN path carries the mesh.
      EmitState("unsupported");
      return false;
    }
  }

  // PERIPHERAL: publish the ffe0 service (write char ffe1, notify char ffe2)
  // and advertise it so phones discover this PC exactly like an Android.
  void StartPeripheral() {
    if (provider_) return;
    auto op = GattServiceProvider::CreateAsync(kServiceUuid).get();
    if (op.Error() != BluetoothError::Success) {
      throw hresult_error(E_FAIL);
    }
    provider_ = op.ServiceProvider();

    GattLocalCharacteristicParameters write_params;
    write_params.CharacteristicProperties(
        GattCharacteristicProperties::Write |
        GattCharacteristicProperties::WriteWithoutResponse);
    auto write_char = provider_.Service()
                          .CreateCharacteristicAsync(kTxUuid, write_params)
                          .get()
                          .Characteristic();
    write_char.WriteRequested(
        [this](GattLocalCharacteristic const&,
               GattWriteRequestedEventArgs const& args) {
          // Delegado threadpool: NADA puede escapar (mataría el proceso) y
          // GetRequestAsync devuelve null si la sesión GATT ya se cerró.
          try {
            auto deferral = args.GetDeferral();
            auto request = args.GetRequestAsync().get();
            if (request) {
              auto bytes = FromBuffer(request.Value());
              std::string id =
                  winrt::to_string(args.Session().DeviceId().Id());
              Emit({{flutter::EncodableValue("type"),
                     flutter::EncodableValue("data")},
                    {flutter::EncodableValue("id"),
                     flutter::EncodableValue(id)},
                    {flutter::EncodableValue("bytes"),
                     flutter::EncodableValue(bytes)}});
              if (request.Option() == GattWriteOption::WriteWithResponse) {
                request.Respond();
              }
            }
            deferral.Complete();
          } catch (const hresult_error&) {
            // Peer se desconectó a mitad de escritura — ignorar.
          } catch (const std::exception&) {
          }
        });

    GattLocalCharacteristicParameters notify_params;
    notify_params.CharacteristicProperties(
        GattCharacteristicProperties::Notify);
    notify_char_ = provider_.Service()
                       .CreateCharacteristicAsync(kRxUuid, notify_params)
                       .get()
                       .Characteristic();

    GattServiceProviderAdvertisingParameters adv;
    adv.IsConnectable(true);
    adv.IsDiscoverable(true);
    provider_.StartAdvertising(adv);
  }

  // CENTRAL: watch for peers advertising ffe0 and report them to Dart, which
  // then calls connect() — mirroring the Kotlin scan callback flow.
  void StartWatcher() {
    if (watcher_) return;
    watcher_ = BluetoothLEAdvertisementWatcher();
    watcher_.ScanningMode(BluetoothLEScanningMode::Active);
    watcher_.Received(
        [this](BluetoothLEAdvertisementWatcher const&,
               BluetoothLEAdvertisementReceivedEventArgs const& args) {
          try {
            for (auto const& uuid : args.Advertisement().ServiceUuids()) {
              if (uuid == kServiceUuid) {
                std::string id = AddressToId(args.BluetoothAddress());
                {
                  // Throttle por peer, NO dedup permanente: Dart reintenta
                  // conexiones fallidas al siguiente aviso.
                  std::lock_guard<std::mutex> lock(mutex_);
                  ULONGLONG now = GetTickCount64();
                  auto it = last_peer_emit_.find(id);
                  if (it != last_peer_emit_.end() &&
                      now - it->second < kPeerReemitMs) {
                    return;
                  }
                  last_peer_emit_[id] = now;
                }
                Emit({{flutter::EncodableValue("type"),
                       flutter::EncodableValue("peer")},
                      {flutter::EncodableValue("id"),
                       flutter::EncodableValue(id)}});
                break;
              }
            }
          } catch (const hresult_error&) {
          } catch (const std::exception&) {
          }
        });
    watcher_.Start();
  }

  bool Connect(const std::string& id) {
    if (id.empty()) return false;
    try {
      uint64_t addr = std::stoull(id, nullptr, 16);
      auto device = BluetoothLEDevice::FromBluetoothAddressAsync(addr).get();
      if (!device) return false;
      auto services = device.GetGattServicesForUuidAsync(kServiceUuid)
                          .get()
                          .Services();
      if (services.Size() == 0) return false;
      auto service = services.GetAt(0);
      Peer peer;
      peer.device = device;
      for (auto const& c : service.GetCharacteristicsForUuidAsync(kTxUuid)
                               .get()
                               .Characteristics()) {
        peer.tx = c;
      }
      for (auto const& c : service.GetCharacteristicsForUuidAsync(kRxUuid)
                               .get()
                               .Characteristics()) {
        peer.rx = c;
      }
      if (!peer.tx || !peer.rx) return false;
      auto status =
          peer.rx
              .WriteClientCharacteristicConfigurationDescriptorAsync(
                  GattClientCharacteristicConfigurationDescriptorValue::
                      Notify)
              .get();
      if (status != GattCommunicationStatus::Success) return false;
      peer.rx_token = peer.rx.ValueChanged(
          [this, id](GattCharacteristic const&,
                     GattValueChangedEventArgs const& args) {
            try {
              Emit({{flutter::EncodableValue("type"),
                     flutter::EncodableValue("data")},
                    {flutter::EncodableValue("id"),
                     flutter::EncodableValue(id)},
                    {flutter::EncodableValue("bytes"),
                     flutter::EncodableValue(
                         FromBuffer(args.CharacteristicValue()))}});
            } catch (const hresult_error&) {
            } catch (const std::exception&) {
            }
          });
      std::lock_guard<std::mutex> lock(mutex_);
      peers_[id] = std::move(peer);
      return true;
    } catch (const hresult_error&) {
      return false;
    } catch (const std::exception&) {
      return false;
    }
  }

  void Disconnect(const std::string& id) {
    Peer peer;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      auto it = peers_.find(id);
      if (it == peers_.end()) return;
      peer = std::move(it->second);
      peers_.erase(it);
    }
    try {
      if (peer.rx && peer.rx_token) peer.rx.ValueChanged(peer.rx_token);
      if (peer.device) peer.device.Close();
    } catch (const hresult_error&) {
    }
  }

  bool Send(const std::string& id, const std::vector<uint8_t>& bytes) {
    if (id.empty() || bytes.empty()) return false;
    GattCharacteristic tx{nullptr};
    {
      std::lock_guard<std::mutex> lock(mutex_);
      auto it = peers_.find(id);
      if (it != peers_.end()) tx = it->second.tx;
    }
    try {
      if (tx) {
        tx.WriteValueAsync(ToBuffer(bytes),
                           GattWriteOption::WriteWithoutResponse)
            .get();
        return true;
      }
      // No central link for this id: the peer connected to US as a central
      // (e.g. an iPhone, which has no connectable address). Answer with
      // notifications to every subscribed client — mirror of the Kotlin
      // server return-path.
      if (notify_char_) {
        notify_char_.NotifyValueAsync(ToBuffer(bytes)).get();
        return true;
      }
      return false;
    } catch (const hresult_error&) {
      return false;
    }
  }

  void Stop() {
    try {
      if (watcher_) {
        watcher_.Stop();
        watcher_ = nullptr;
      }
      if (provider_) {
        provider_.StopAdvertising();
        provider_ = nullptr;
        notify_char_ = nullptr;
      }
    } catch (const hresult_error&) {
    }
    std::map<std::string, Peer> peers;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      peers.swap(peers_);
      last_peer_emit_.clear();
    }
    for (auto& [id, p] : peers) {
      try {
        if (p.rx && p.rx_token) p.rx.ValueChanged(p.rx_token);
        if (p.device) p.device.Close();
      } catch (const hresult_error&) {
      }
    }
  }

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  std::deque<flutter::EncodableMap> pending_events_;
  std::deque<std::pair<MethodResultPtr, bool>> pending_replies_;
  std::mutex mutex_;
  UINT_PTR timer_id_ = 0;

  GattServiceProvider provider_{nullptr};
  GattLocalCharacteristic notify_char_{nullptr};
  BluetoothLEAdvertisementWatcher watcher_{nullptr};
  std::map<std::string, Peer> peers_;
  std::map<std::string, ULONGLONG> last_peer_emit_;
};

BleMeshBridge* BleMeshBridge::instance_ = nullptr;

BleMeshBridge* g_bridge = nullptr;

}  // namespace

void RegisterBleMeshBridge(flutter::BinaryMessenger* messenger) {
  if (!g_bridge) g_bridge = new BleMeshBridge(messenger);
}
