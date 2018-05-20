import QuartzCore
import UIKit

public enum Renderer {
    
    public static func render(
        filename: String,
        animation: Animation<Unit>,
        fps: Double,
        canvas: UIView,
        cb: @escaping (URL) -> ()
    ) {
        var currentStep : Int = 0
        let totalSteps = Int(animation.duration * fps)
        print("Recording for frames", totalSteps)
        var imgs : [UIImage] = []
        
        while currentStep <= totalSteps {
            let next = Double(currentStep) / Double(totalSteps)
            let _ = animation.value((next < 1) ? next : 1)
            imgs.append(snapshot(view: canvas))
            currentStep += 1
        }
        
        let videoGenerator = VideoGenerator.current
        videoGenerator.scaleWidth = canvas.bounds.width
        videoGenerator.fileName = filename
        print("I think seconds", animation.duration)
        videoGenerator.videoDurationInSeconds = animation.duration
        print("Length: ", imgs.count)
        videoGenerator.generate(withImages: imgs, andAudios: [], andType: VideoGenerator.VideoGeneratorType.single, { (progress) in
            print(progress)
        }, success: { (url) in
            cb(url)
        }) { (error) in
            print(error)
        }
    }
}

public final class Drive: NSObject {
  /// `maxSteps` is for use in a playground only. It kills the display link after that many steps so that
  /// playgrounds don't crash.
  private var maxSteps: Int
  private var displayLink: CADisplayLink!
  private var animations: [(startTime: CFAbsoluteTime, Animation<Unit>)] = []

  public init(maxSteps: Int = Int.max) {
    self.maxSteps = maxSteps
    super.init()
    self.displayLink = UIScreen.main.displayLink(withTarget: self, selector: #selector(step(_:)))
    //CADisplayLink(target: self, selector: #selector(step(_:)))
    self.displayLink.add(to: RunLoop.main, forMode: .commonModes)
  }

  public func append(animation: Animation<Unit>) {
    guard animation.duration > 0 else { return }

    DispatchQueue.main.async {
      self.animations.append((self.displayLink.targetTimestamp, animation))
    }
  }

  private var currentSteps = 0
  @objc private func step(_ displayLink: CADisplayLink) {
    self.currentSteps += 1
    if self.currentSteps > self.maxSteps {
      self.displayLink.invalidate()
    }

    let time = displayLink.targetTimestamp
    var indicesToRemove: [Int] = []

    for (idx, startTimeAndAnimation) in self.animations.enumerated() {
      let (startTime, animation) = startTimeAndAnimation
      let t = (time - startTime) / animation.duration
      if t <= 1 {
        _ = animation.value(t)
      } else {
        _ = animation.value(1)
        indicesToRemove.append(idx)
      }
    }

    indicesToRemove.reversed().forEach { self.animations.remove(at: $0) }
  }
}
