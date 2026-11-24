import SwiftUI

struct HeadSelectionOverlay: View {
    @Binding var placement: HeadPlacement
    let imageSize: CGSize
    let settings: PhotoSettings
    private var isValid: Bool { placement.framingError(in: imageSize, settings: settings) == nil }
    private var boxColor: Color { isValid ? .green : .red }
    @State private var dragOrigin: CGRect?

    var body: some View {
        GeometryReader { proxy in
            let rectangle = placement.selection(in: imageSize)
            let displayed = CGRect(x: rectangle.minX * proxy.size.width, y: rectangle.minY * proxy.size.height,
                                   width: rectangle.width * proxy.size.width, height: rectangle.height * proxy.size.height)
            ZStack(alignment: .topLeading) {
                // This is the only move target. Sibling corner handles receive their
                // own resize gestures; touches outside the box still scroll the page.
                Rectangle().fill(boxColor.opacity(0.07))
                    .overlay { Rectangle().stroke(.black.opacity(0.6), lineWidth: 4) }
                    .overlay { Rectangle().stroke(boxColor, lineWidth: 2) }
                    .frame(width: displayed.width, height: displayed.height)
                    .contentShape(Rectangle())
                    .highPriorityGesture(drag(in: proxy.size))
                    .position(x: displayed.midX, y: displayed.midY)
                ForEach(HeadBoxGeometry.Corner.allCases, id: \.self) { corner in
                    RoundedRectangle(cornerRadius: 2).fill(boxColor)
                        .frame(width: 14, height: 14)
                        .overlay { RoundedRectangle(cornerRadius: 2).stroke(.black.opacity(0.7), lineWidth: 1) }
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                        .highPriorityGesture(drag(in: proxy.size, corner: corner))
                        .position(point(corner, in: displayed))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(AppText.localized("头部定位方框")))
        .accessibilityValue(Text(AppText.localized(isValid ? "取景范围符合当前规格" : "取景范围不足，请调整")))
        .accessibilityHint(Text(AppText.localized("拖动框内移动，拖动四角缩放；上下调整操作可改变方框大小，也可使用自定操作移动方框。")))
        .accessibilityAdjustableAction { direction in
            let rectangle = placement.selection(in: imageSize)
            let amount: CGFloat = direction == .increment ? 0.01 : -0.01
            placement = placement.replacingSelection(rectangle.insetBy(dx: -amount, dy: -amount))
        }
        .accessibilityAction(named: Text(AppText.localized("向左移动"))) { move(dx: -0.01, dy: 0) }
        .accessibilityAction(named: Text(AppText.localized("向右移动"))) { move(dx: 0.01, dy: 0) }
        .accessibilityAction(named: Text(AppText.localized("向上移动"))) { move(dx: 0, dy: -0.01) }
        .accessibilityAction(named: Text(AppText.localized("向下移动"))) { move(dx: 0, dy: 0.01) }
    }

    private func drag(in size: CGSize, corner: HeadBoxGeometry.Corner? = nil) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard size.width > 0, size.height > 0 else { return }
                let initial = dragOrigin ?? placement.selection(in: imageSize)
                if dragOrigin == nil { dragOrigin = initial }
                let delta = CGSize(width: value.translation.width / size.width, height: value.translation.height / size.height)
                let result: CGRect
                if let corner {
                    let minimum = CGSize(width: min(initial.width, max(0.04, 32 / size.width)),
                                         height: min(initial.height, max(0.04, 32 / size.height)))
                    result = HeadBoxGeometry.resized(initial, corner: corner, by: delta, minimum: minimum)
                } else {
                    result = HeadBoxGeometry.moved(initial, by: delta)
                }
                placement = placement.replacingSelection(result)
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private func point(_ corner: HeadBoxGeometry.Corner, in rect: CGRect) -> CGPoint {
        switch corner {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    private func move(dx: CGFloat, dy: CGFloat) {
        placement = placement.replacingSelection(HeadBoxGeometry.moved(placement.selection(in: imageSize), by: CGSize(width: dx, height: dy)))
    }
}
