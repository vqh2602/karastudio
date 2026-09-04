import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    var windowFrame = self.frame
    windowFrame.size = NSSize(width: 1440, height: 900)
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 1100, height: 700)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
