Pod::Spec.new do |s|
  s.name         = "MTHawkeye"
  s.version      = "0.12.3"
  s.summary      = "Profiling/Debugging assist tools for iOS."

  s.description  = <<-DESC
    MTHawkeye is profiling/debugging assist tools for iOS. It's designed to help iOS developers improve development productivity and assist in optimizing the App performance.
                   DESC

  s.homepage     = "https://github.com/meitu/MTHawkeye"
  s.license      = {
    :type => 'Copyright',
    :text => <<-LICENSE
      © 2008-present, Meitu, Inc. All rights reserved.
    LICENSE
  }

  s.author       = { "Euan Chan" => "cqh@meitu.com" }

  s.platform     = :ios, "9.0"

  s.source       = { :git => "https://github.com/meitu/MTHawkeye.git", :tag => "#{s.version}" }

  s.default_subspec = 'DefaultPluginsExcludeGL'

  # ――― Default ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.subspec 'DefaultPlugins' do |sp|
    sp.dependency 'MTHawkeye/DefaultPluginsWithoutLog'
    sp.dependency 'CocoaLumberjack'
  end

  s.subspec 'DefaultPluginsExcludeGL' do |sp|
    sp.dependency 'MTHawkeye/DefaultPluginsWithoutLogAndGL'
    sp.dependency 'CocoaLumberjack'
  end

  s.subspec 'DefaultPluginsWithoutLog' do |sp|
    sp.dependency 'MTHawkeye/DefaultPluginsWithoutLogAndGL'
    sp.dependency 'MTHawkeye/GraphicsPlugins'

    sp.pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MTH_INCLUDE_GLTRACE=1' }

  end

  # without GraphicsPlugins( GLTrace )
  s.subspec 'DefaultPluginsWithoutLogAndGL' do |sp|
    sp.public_header_files = 'MTHawkeye/DefaultPlugins/**/*.{h}'
    sp.source_files  = 'MTHawkeye/DefaultPlugins/**/*.{h,m,mm}'

    sp.dependency 'MTHawkeye/Core'
    sp.dependency 'MTHawkeye/UISkeleton'

    sp.dependency 'MTHawkeye/MemoryPlugins'
    sp.dependency 'MTHawkeye/TimeConsumingPlugins'
    sp.dependency 'MTHawkeye/EnergyPlugins'
    sp.dependency 'MTHawkeye/NetworkPlugins'
    sp.dependency 'MTHawkeye/StorageMonitorPlugins'

    sp.dependency 'MTHawkeye/FLEXExtension'

  end

  # ――― Basic ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.subspec 'Core' do |sp|
    sp.public_header_files = 'MTHawkeye/Core/**/*.{h}'
    sp.source_files = 'MTHawkeye/Core/**/*.{h,m}'
    sp.dependency 'MTHawkeye/Utils'
  end

  s.subspec 'UISkeleton' do |ui|
    ui.public_header_files = 'MTHawkeye/UISkeleton/**/*.{h}'
    ui.source_files = 'MTHawkeye/UISkeleton/**/*.{h,m}'
    ui.dependency 'MTHawkeye/Core'
    ui.framework = 'CoreGraphics', 'QuartzCore', 'UIKit', 'WebKit'
    ui.libraries = 'z'
  end

  s.subspec 'Utils' do |sp|
      sp.public_header_files = 'MTHawkeye/Utils/*.{h}'
      sp.source_files = 'MTHawkeye/Utils/**/*.{h,m,mm}'
      sp.dependency 'MTAppenderFile'
      sp.framework = 'Foundation', 'SystemConfiguration'

      cpp_files = 'MTHawkeye/Utils/*.{cpp,hpp}'
      sp.exclude_files = cpp_files
      sp.subspec 'cpp' do |cpp|
        # tricks to ignore public_header_files.
        cpp.public_header_files = 'MTHawkeye/Utils/MTHawkeyeEmptyHeaderForCPP.hpp'
        cpp.source_files = cpp_files
        cpp.libraries = "stdc++"
      end
  end

  s.subspec 'StackBacktrace' do |sp|
      sp.public_header_files =
        'MTHawkeye/StackBacktrace/MTHStackFrameSymbolicsRemote.h',
        'MTHawkeye/StackBacktrace/mth_stack_backtrace.h'

      sp.source_files = 'MTHawkeye/StackBacktrace/**/*.{h,m,mm,cpp}'
      sp.dependency 'MTHawkeye/Utils'
      sp.framework = 'Foundation'
  end

  # ―――++ Plugins ++――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  # ――― Memory ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.subspec 'MemoryPlugins' do |mem|

    # unexpected living object sniffer.
    mem.subspec 'LivingObjectSniffer' do |los|
      los.subspec 'Core' do |core|
        core.public_header_files = 'MTHawkeye/MemoryPlugins/LivingObjectSniffer/Core/*.{h}'
        core.source_files = 'MTHawkeye/MemoryPlugins/LivingObjectSniffer/Core/*.{h,m,mm}'
        core.dependency 'MTHawkeye/Utils'
      end

      los.subspec 'HawkeyeCore' do |hc|
        hc.public_header_files = 'MTHawkeye/MemoryPlugins/LivingObjectSniffer/HawkeyeCore/*.{h}'
        hc.source_files = 'MTHawkeye/MemoryPlugins/LivingObjectSniffer/HawkeyeCore/*.{h,m}'
        hc.dependency 'MTHawkeye/Core'
        hc.dependency 'MTHawkeye/MemoryPlugins/LivingObjectSniffer/Core'
      end

      los.subspec 'HawkeyeUI' do |ui|
        ui.public_header_files = 'MTHawkeye/MemoryPlugins/LivingObjectSniffer/**/*.{h}'
        ui.source_files = 'MTHawkeye/MemoryPlugins/LivingObjectSniffer/**/*.{h,m}'
        ui.dependency 'MTHawkeye/UISkeleton'
        ui.dependency 'MTHawkeye/MemoryPlugins/LivingObjectSniffer/HawkeyeCore'
        ui.dependency 'FBRetainCycleDetector'
      end
    end

    # memory allocation events tracer
    mem.subspec 'Allocations' do |alloc|
      alloc.subspec 'Core' do |core|
        core.public_header_files = 'MTHawkeye/MemoryPlugins/Allocations/Core/MTHAllocations.h'
        core.source_files = 'MTHawkeye/MemoryPlugins/Allocations/Core/*.{h,c,cpp,m,mm}'
        core.dependency 'MTHawkeye/Utils'
        core.dependency 'MTHawkeye/StackBacktrace'

        core.libraries = "stdc++"

        non_arc_files   = 'MTHawkeye/MemoryPlugins/Allocations/Core/NSObject+MTHAllocTrack.{h,m}'
        core.exclude_files = non_arc_files
        core.subspec 'no-arc' do |sna|
            sna.requires_arc = false
            sna.source_files = non_arc_files
            sna.dependency 'MTHawkeye/Utils'
        end
      end

      alloc.subspec 'HawkeyeCore' do |hc|
        hc.public_header_files = 'MTHawkeye/MemoryPlugins/Allocations/HawkeyeCore/*.{h}'
        hc.source_files = 'MTHawkeye/MemoryPlugins/Allocations/HawkeyeCore/*.{h,m}'
        hc.dependency 'MTHawkeye/Core'
        hc.dependency 'MTHawkeye/MemoryPlugins/Allocations/Core'
      end

      alloc.subspec 'HawkeyeUI' do |ui|
        ui.public_header_files = 'MTHawkeye/MemoryPlugins/Allocations/HawkeyeUI/*.{h}'
        ui.source_files = 'MTHawkeye/MemoryPlugins/Allocations/HawkeyeUI/*.{h,m}'
        ui.dependency 'MTHawkeye/UISkeleton'
        ui.dependency 'MTHawkeye/MemoryPlugins/Allocations/Core'
        ui.dependency 'MTHawkeye/MemoryPlugins/Allocations/HawkeyeCore'
      end
    end
  end # MemoryPlugins

  # ――― Time Consuming ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.subspec 'TimeConsumingPlugins' do |tc|

    # FPS Trace
    tc.subspec 'FPSTrace' do |fps|
      fps.subspec 'Core' do |core|
        core.public_header_files = 'MTHawkeye/TimeConsumingPlugins/FPSTrace/Core/*.{h}'
        core.source_files = 'MTHawkeye/TimeConsumingPlugins/FPSTrace/Core/*.{h,m}'
        core.dependency 'MTHawkeye/Core'
        core.framework = 'QuartzCore'
      end

      fps.subspec 'HawkeyeCore' do |hc|
        hc.public_header_files = 'MTHawkeye/TimeConsumingPlugins/FPSTrace/HawkeyeCore/*.{h}'
        hc.source_files = 'MTHawkeye/TimeConsumingPlugins/FPSTrace/HawkeyeCore/*.{h,m}'
        hc.dependency 'MTHawkeye/Core'
        hc.dependency 'MTHawkeye/TimeConsumingPlugins/FPSTrace/Core'
      end

      fps.subspec 'HawkeyeUI' do |ui|
        ui.public_header_files = 'MTHawkeye/TimeConsumingPlugins/FPSTrace/HawkeyeUI/*.{h}'
        ui.source_files = 'MTHawkeye/TimeConsumingPlugins/FPSTrace/HawkeyeUI/*.{h,m}'
        ui.dependency 'MTHawkeye/Core'
        ui.dependency 'MTHawkeye/UISkeleton'
        ui.dependency 'MTHawkeye/TimeConsumingPlugins/FPSTrace/Core'
        ui.dependency 'MTHawkeye/TimeConsumingPlugins/FPSTrace/HawkeyeCore'
      end
    end

    # ANR Trace
    tc.subspec 'ANRTrace' do |anr|
      anr.subspec 'Core' do |core|
        core.public_header_files = 'MTHawkeye/TimeConsumingPlugins/ANRTrace/Core/*.{h}'
        core.source_files = 'MTHawkeye/TimeConsumingPlugins/ANRTrace/Core/*.{h,m,mm}'
        core.dependency 'MTHawkeye/Utils'
        core.dependency 'MTHawkeye/StackBacktrace'
        core.dependency 'MTHawkeye/Core' # AppStat.
      end

      anr.subspec 'HawkeyeCore' do |hc|
        hc.public_header_files = 'MTHawkeye/TimeConsumingPlugins/ANRTrace/HawkeyeCore/*.{h}'
        hc.source_files = 'MTHawkeye/TimeConsumingPlugins/ANRTrace/HawkeyeCore/*.{h,m}'
        hc.dependency 'MTHawkeye/Core'
        hc.dependency 'MTHawkeye/TimeConsumingPlugins/ANRTrace/Core'
      end

      anr.subspec 'HawkeyeUI' do |ui|
        ui.public_header_files = 'MTHawkeye/TimeConsumingPlugins/ANRTrace/HawkeyeUI/*.{h}'
        ui.source_files = 'MTHawkeye/TimeConsumingPlugins/ANRTrace/HawkeyeUI/*.{h,m,mm}'
        ui.dependency 'MTHawkeye/Core'
        ui.dependency 'MTHawkeye/UISkeleton'
        ui.dependency 'MTHawkeye/TimeConsumingPlugins/ANRTrace/HawkeyeCore'
      end
    end

    # Objective-C Method Call Trace
    tc.subspec 'ObjcCallTrace' do |call|
      call.subspec 'Core' do |core|
        core.public_header_files = 'MTHawkeye/TimeConsumingPlugins/ObjcCallTrace/Core/*.{h}'
        core.source_files = 'MTHawkeye/TimeConsumingPlugins/ObjcCallTrace/Core/*.{h,m,c}'
        core.dependency 'MTHawkeye/Utils'
        core.dependency 'fishhook', '~> 0.2'
      end

      call.subspec 'HawkeyeCore' do |hc|
          hc.public_header_files = 'MTHawkeye/TimeConsumingPlugins/ObjcCallTrace/HawkeyeCore/*.{h}'
          hc.source_files = 'MTHawkeye/TimeConsumingPlugins/ObjcCallTrace/HawkeyeCore/*.{h,m}'
          hc.dependency 'MTHawkeye/Core'
          hc.dependency 'MTHawkeye/TimeConsumingPlugins/ObjcCallTrace/Core'
      end
    end

    # TimeProfiler for UI Thread
    tc.subspec 'UITimeProfiler' do |anr|
      anr.subspec 'Core' do |core|
        core.public_header_files = 'MTHawkeye/TimeConsumingPlugins/UITimeProfiler/Core/*.{h}'
        core.source_files = 'MTHawkeye/TimeConsumingPlugins/UITimeProfiler/Core/*.{h,m}'
        core.dependency 'MTHawkeye/Core'
      end

      anr.subspec 'HawkeyeCore' do |hc|
        hc.public_header_files = 'MTHawkeye/TimeConsumingPlugins/UITimeProfiler/HawkeyeCore/*.{h}'
        hc.source_files = 'MTHawkeye/TimeConsumingPlugins/UITimeProfiler/HawkeyeCore/*.{h,m}'
        hc.dependency 'MTHawkeye/Core'
        hc.dependency 'MTHawkeye/TimeConsumingPlugins/UITimeProfiler/Core'
      end

      anr.subspec 'HawkeyeUI' do |ui|
        ui.public_header_files = 'MTHawkeye/TimeConsumingPlugins/UITimeProfiler/HawkeyeUI/*.{h}'
        ui.source_files = 'MTHawkeye/TimeConsumingPlugins/UITimeProfiler/HawkeyeUI/*.{h,m}'
        ui.dependency 'MTHawkeye/Core'
        ui.dependency 'MTHawkeye/UISkeleton'
        ui.dependency 'MTHawkeye/TimeConsumingPlugins/ObjcCallTrace'
        ui.dependency 'MTHawkeye/TimeConsumingPlugins/UITimeProfiler/HawkeyeCore'
      end
    end

  end # TimeConsumingPlugins

  # ――― Energy ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.subspec 'EnergyPlugins' do |ep|
    # CPU Trace
    ep.subspec 'CPUTrace' do |cpu|
      cpu.subspec 'Core' do |core|
        # tricks: *.{h} will match hpp files, which will copy to xx-umbrella.h and cause compile error under swift project
        core.public_header_files = 'MTHawkeye/EnergyPlugins/CPUTrace/Core/MTHCPUTracePublicHeader.{h}'
        core.source_files = 'MTHawkeye/EnergyPlugins/CPUTrace/Core/*.{h,m,mm}'
        core.dependency 'MTHawkeye/Core'
        core.dependency 'MTHawkeye/StackBacktrace'
        core.libraries = "stdc++"
      end

      cpu.subspec 'HawkeyeCore' do |hc|
        hc.public_header_files = 'MTHawkeye/EnergyPlugins/CPUTrace/HawkeyeCore/*.{h}'
        hc.source_files = 'MTHawkeye/EnergyPlugins/CPUTrace/HawkeyeCore/*.{h,m,mm}'
        hc.dependency 'MTHawkeye/Core'
        hc.dependency 'MTHawkeye/EnergyPlugins/CPUTrace/Core'
      end

      cpu.subspec 'HawkeyeUI' do |ui|
        ui.public_header_files = 'MTHawkeye/EnergyPlugins/CPUTrace/HawkeyeUI/*.{h}'
        ui.source_files = 'MTHawkeye/EnergyPlugins/CPUTrace/HawkeyeUI/*.{h,m,mm}'
        ui.dependency 'MTHawkeye/Core'
        ui.dependency 'MTHawkeye/UISkeleton'
        ui.dependency 'MTHawkeye/EnergyPlugins/CPUTrace/HawkeyeCore'
      end
    end
    
    # BacktroundTask Tracing
    ep.subspec 'BackgroundTaskTrace' do |bg|
      bg.subspec 'Core' do |core|
        core.public_header_files = 'MTHawkeye/EnergyPlugins/BackgroundTaskTrace/Core/*.{h}'
        core.source_files = 'MTHawkeye/EnergyPlugins/BackgroundTaskTrace/Core/*.{h,m}'
        core.dependency 'MTHawkeye/Utils'
      end

      bg.subspec 'HawkeyeCore' do |hc|
        hc.public_header_files = 'MTHawkeye/EnergyPlugins/BackgroundTaskTrace/HawkeyeCore/*.{h}'
        hc.source_files = 'MTHawkeye/EnergyPlugins/BackgroundTaskTrace/HawkeyeCore/*.{h,m}'
        hc.dependency 'MTHawkeye/Core'
        hc.dependency 'MTHawkeye/StackBacktrace'
        hc.dependency 'MTHawkeye/EnergyPlugins/BackgroundTaskTrace/Core'
      end
      
      bg.subspec 'HawkeyeUI' do |ui|
        ui.public_header_files = 'MTHawkeye/EnergyPlugins/BackgroundTaskTrace/HawkeyeUI/*.{h}'
        ui.source_files = 'MTHawkeye/EnergyPlugins/BackgroundTaskTrace/HawkeyeUI/*.{h,m,mm}'
        ui.dependency 'MTHawkeye/Core'
        ui.dependency 'MTHawkeye/UISkeleton'
        ui.dependency 'MTHawkeye/EnergyPlugins/BackgroundTaskTrace/HawkeyeCore'
      end
    end
  end # EnergyPlugins

  # ――― Graphics ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.subspec 'GraphicsPlugins' do |gp|
    gp.subspec 'OpenGLTrace' do |sp|
      sp.public_header_files = 'MTHawkeye/GraphicsPlugins/OpenGLTrace/**/*.{h}'
      sp.source_files = 'MTHawkeye/GraphicsPlugins/OpenGLTrace/**/*.{h,m}'
      sp.dependency 'MTGLDebug'
      sp.dependency 'MTHawkeye/UISkeleton'
    end
  end # GraphicsPlugins

  # ――― Network ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.subspec 'NetworkPlugins' do |net|
    # Networking Monitor
    net.subspec 'Monitor' do |mnt|
      mnt.subspec 'Core' do |core|
        core.public_header_files = 'MTHawkeye/NetworkPlugins/Monitor/Core/**/*.{h}'
        core.source_files = 'MTHawkeye/NetworkPlugins/Monitor/Core/**/*.{h,m}'
        core.dependency 'MTHawkeye/Core'
        core.framework = 'ImageIO', 'CFNetwork'
        core.libraries = 'z'
      end

      mnt.subspec 'HawkeyeCore' do |hc|
        hc.public_header_files = 'MTHawkeye/NetworkPlugins/Monitor/HawkeyeCore/*.{h}'
        hc.source_files = 'MTHawkeye/NetworkPlugins/Monitor/HawkeyeCore/*.{h,m}'
        hc.dependency 'MTHawkeye/Core'
        hc.dependency 'MTHawkeye/NetworkPlugins/Monitor/Core'
      end
    end

    # Networking performance inspect
    net.subspec 'Inspect' do |ins|
      ins.subspec 'Core' do |core|
          core.public_header_files = 'MTHawkeye/NetworkPlugins/Inspect/Core/*.{h}'
          core.source_files = 'MTHawkeye/NetworkPlugins/Inspect/Core/*.{h,m}'
          core.dependency 'MTHawkeye/Core'
          core.dependency 'MTHawkeye/NetworkPlugins/Monitor'
      end

      ins.subspec 'HawkeyeCore' do |hc|
          hc.public_header_files = 'MTHawkeye/NetworkPlugins/Inspect/HawkeyeCore/*.{h}'
          hc.source_files = 'MTHawkeye/NetworkPlugins/Inspect/HawkeyeCore/*.{h,m}'
          hc.dependency 'MTHawkeye/Core'
          hc.dependency 'MTHawkeye/NetworkPlugins/Inspect/Core'
      end
    end

    net.subspec 'HawkeyeUI' do |ui|
      ui.public_header_files = 'MTHawkeye/NetworkPlugins/HawkeyeUI/**/*.{h}'
      ui.source_files = 'MTHawkeye/NetworkPlugins/HawkeyeUI/**/*.{h,m}'
      ui.dependency 'MTHawkeye/NetworkPlugins/Monitor'
      ui.dependency 'MTHawkeye/NetworkPlugins/Inspect'
      ui.dependency 'MTHawkeye/UISkeleton'
      ui.dependency 'FLEX', '4.1.1'
      ui.libraries = "sqlite3"
      ui.framework = 'QuartzCore'
    end
  end # NetworkPlugins

  # ――― Storage ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.subspec 'StorageMonitorPlugins' do |store|
      store.subspec 'DirectoryWatcher' do |dw|
          dw.subspec 'Core' do |core|
              core.public_header_files = 'MTHawkeye/StorageMonitorPlugins/DirectoryWatcher/Core/*.{h}'
              core.source_files = 'MTHawkeye/StorageMonitorPlugins/DirectoryWatcher/Core/*.{h,m}'
              core.dependency 'MTHawkeye/Utils'
          end

          dw.subspec 'HawkeyeCore' do |hc|
              hc.public_header_files = 'MTHawkeye/StorageMonitorPlugins/DirectoryWatcher/HawkeyeCore/*.{h}'
              hc.source_files = 'MTHawkeye/StorageMonitorPlugins/DirectoryWatcher/HawkeyeCore/*.{h,m}'
              hc.dependency 'MTHawkeye/Core'
              hc.dependency 'MTHawkeye/StorageMonitorPlugins/DirectoryWatcher/Core'
          end

          dw.subspec 'HawkeyeUI' do |ui|
              ui.public_header_files = 'MTHawkeye/StorageMonitorPlugins/DirectoryWatcher/HawkeyeUI/*.{h}'
              ui.source_files = 'MTHawkeye/StorageMonitorPlugins/DirectoryWatcher/HawkeyeUI/*.{h,m}'
              ui.dependency 'MTHawkeye/UISkeleton'
              ui.dependency 'MTHawkeye/StorageMonitorPlugins/DirectoryWatcher/HawkeyeCore'
              ui.dependency 'MTHawkeye/FLEXExtension'
          end
      end
  end # StorageMonitorPlugins

  # ――― FLEX Extension ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.subspec 'FLEXExtension' do |flex|
      flex.public_header_files = 'MTHawkeye/FLEXExtension/**/*.{h}'
      flex.source_files = 'MTHawkeye/FLEXExtension/**/*.{h,m}'
      flex.dependency 'FLEX', '4.1.1'
      flex.dependency 'MTHawkeye/UISkeleton'
      flex.libraries = "sqlite3"
  end

  s.requires_arc = true

end
