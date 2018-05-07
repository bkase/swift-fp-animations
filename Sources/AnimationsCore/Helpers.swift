import CoreGraphics

public func linear(from a: CGFloat, to b: CGFloat, in duration: CFAbsoluteTime) -> Animation<CGFloatAverage> {
      return Animation.runnable(duration: duration) { t in
        FloatAverage(a * (1 - CGFloat(t)) + b * CGFloat(t))
      }
}

