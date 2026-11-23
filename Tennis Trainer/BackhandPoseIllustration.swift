import SwiftUI

/// Schematic examples, separate from the player's measured arm diagram.
struct BackhandPoseIllustration: View {
  enum Phase { case ready, backswing, checkpoint }
  let phase: Phase

  var body: some View {
    Canvas { context, size in
      let scale = min(size.width / 230, size.height / 190)
      let offset = CGPoint(x: (size.width - 230 * scale) / 2, y: (size.height - 190 * scale) / 2)
      func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: offset.x + x * scale, y: offset.y + y * scale)
      }
      func line(_ vertices: [(CGFloat, CGFloat)], _ color: Color, _ weight: CGFloat = 5) {
        var path = Path()
        path.addLines(vertices.map { point($0.0, $0.1) })
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: weight * scale, lineCap: .round, lineJoin: .round))
      }
      func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ color: Color) {
        let center = point(x, y)
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius * scale, y: center.y - radius * scale,
                                           width: radius * 2 * scale, height: radius * 2 * scale)), with: .color(color))
      }

      // Torso and legs provide context without implying a universal stance.
      circle(88, 27, 13, .secondary.opacity(0.45))
      line([(88, 42), (88, 54)], .secondary.opacity(0.5))
      var torso = Path()
      torso.addLines([point(76, 54), point(101, 58), point(103, 113), point(78, 113)])
      torso.closeSubpath()
      context.fill(torso, with: .color(.secondary.opacity(0.13)))
      line([(76, 54), (78, 113), (64, 161), (53, 169)], .secondary.opacity(0.45))
      line([(101, 58), (103, 113), (119, 162), (133, 169)], .secondary.opacity(0.45))
      line([(76, 54), (101, 58)], .secondary.opacity(0.45))
      line([(39, 178), (183, 178)], .secondary.opacity(0.14), 2)

      let top: [(CGFloat, CGFloat)]
      let bottom: [(CGFloat, CGFloat)]
      let racket: [(CGFloat, CGFloat)]
      let head: (CGFloat, CGFloat)
      switch phase {
      case .ready:
        top = [(76, 54), (91, 86), (125, 81)]
        bottom = [(101, 58), (117, 105), (121, 89)]
        racket = [(117, 98), (136, 58)]
        head = (145, 39)
      case .backswing:
        top = [(76, 54), (56, 88), (38, 79)]
        bottom = [(101, 58), (77, 110), (42, 86)]
        racket = [(47, 96), (30, 57)]
        head = (22, 38)
      case .checkpoint:
        top = [(76, 54), (116, 87), (167, 75)]
        bottom = [(101, 58), (121, 104), (164, 83)]
        racket = [(157, 95), (176, 55)]
        head = (184, 35)
      }
      line(racket, .secondary, 3)
      let center = point(head.0, head.1)
      context.stroke(Path(ellipseIn: CGRect(x: center.x - 12 * scale, y: center.y - 20 * scale,
                                           width: 24 * scale, height: 40 * scale)),
                     with: .color(.secondary), lineWidth: 2 * scale)
      line(bottom, .orange)
      line(top, .blue)
      for joint in bottom { circle(joint.0, joint.1, 3.5, .orange) }
      for joint in top { circle(joint.0, joint.1, 3.5, .blue) }
      if phase == .checkpoint {
        let hand = point(166, 79)
        context.stroke(Path(ellipseIn: CGRect(x: hand.x - 12 * scale, y: hand.y - 12 * scale,
                                             width: 24 * scale, height: 24 * scale)),
                       with: .color(.purple), style: StrokeStyle(lineWidth: 2 * scale, dash: [3 * scale, 3 * scale]))
        line([(119, 128), (177, 128), (170, 122)], .purple, 2)
        line([(177, 128), (170, 134)], .purple, 2)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(description)
  }

  private var description: String {
    switch phase {
    case .ready: return "Ready pose: hands together in front of the body, before the backswing. Left top arm in blue, right bottom arm in orange."
    case .backswing: return "Backswing: both hands and the racket move back from ready."
    case .checkpoint: return "Checkpoint: both hands travel forward through the swing, with the left top elbow still comfortably bent. A purple ring marks the hands."
    }
  }
}
