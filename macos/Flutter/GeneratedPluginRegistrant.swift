//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import audio_session
import battery_plus
import file_selector_macos
import flutter_blue_plus_darwin
import flutter_inappwebview_macos
import geolocator_apple
import just_audio
import package_info_plus
import screen_brightness_macos
import wakelock_plus

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AudioSessionPlugin.register(with: registry.registrar(forPlugin: "AudioSessionPlugin"))
  BatteryPlusMacosPlugin.register(with: registry.registrar(forPlugin: "BatteryPlusMacosPlugin"))
  FileSelectorPlugin.register(with: registry.registrar(forPlugin: "FileSelectorPlugin"))
  FlutterBluePlusPlugin.register(with: registry.registrar(forPlugin: "FlutterBluePlusPlugin"))
  InAppWebViewFlutterPlugin.register(with: registry.registrar(forPlugin: "InAppWebViewFlutterPlugin"))
  GeolocatorPlugin.register(with: registry.registrar(forPlugin: "GeolocatorPlugin"))
  JustAudioPlugin.register(with: registry.registrar(forPlugin: "JustAudioPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  ScreenBrightnessMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenBrightnessMacosPlugin"))
  WakelockPlusMacosPlugin.register(with: registry.registrar(forPlugin: "WakelockPlusMacosPlugin"))
}
