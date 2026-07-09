Pod::Spec.new do |s|
  s.name             = 'prepper_native'
  s.version          = '1.1.0'
  s.summary          = 'Motores nativos de Prepper Pad (zstd para ZIM, ppllm para la IA local).'
  s.description      = 'zstd empaquetado como framework dinámico para que Dart FFI lo cargue en iOS; liblzma la provee el SDK de Apple.'
  s.homepage         = 'https://github.com/scottorellana/prepper-pad'
  s.license          = { :type => 'BSD-3-Clause' }
  s.author           = 'Prepper Pad'
  s.source           = { :path => '.' }
  s.platform         = :ios, '14.0'
  s.vendored_frameworks = ['zstd.xcframework', 'ppllm.xcframework']
  # liblzma viene en el SDK de iOS; Metal/Accelerate los usa ppllm.
  s.libraries        = 'lzma'
  s.frameworks       = 'Metal', 'MetalKit', 'Accelerate', 'Foundation'
end
