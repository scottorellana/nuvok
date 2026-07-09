#ifndef RUNNER_BLE_MESH_BRIDGE_H_
#define RUNNER_BLE_MESH_BRIDGE_H_

#include <flutter/binary_messenger.h>

// Registers the prepper/ble_mesh method+event channels backed by WinRT BLE
// (GattServiceProvider for the peripheral role, BluetoothLEAdvertisement-
// Watcher + GattDeviceService for the central role). Mirrors BleMeshBridge.kt
// so a Windows PC joins the mesh next to Android/iPhone/Mac with no network.
void RegisterBleMeshBridge(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_BLE_MESH_BRIDGE_H_
