import UIKit

extension UITableViewCell {
    enum ColorValueChange {
        case ColorValueHue
        case ColorValueSaturation
    }

    func changeBackgroundColorByValue(
        valueChange: ColorValueChange,
        value: CGFloat) {

            var hue:CGFloat = 0.0
            var saturation:CGFloat = 0.0
            var brightness:CGFloat = 0.0
            var alpha:CGFloat = 0.0

            _ = self.backgroundColor?.getHue(
                &hue,
                saturation: &saturation,
                brightness: &brightness,
                alpha: &alpha)

            var newColor: UIColor?

            switch valueChange {
            case .ColorValueHue:
                newColor = UIColor(
                    hue: value,
                    saturation: saturation,
                    brightness: 1.0,
                    alpha: 1.0)
            case .ColorValueSaturation:
                newColor = UIColor(
                    hue: hue,
                    saturation: value,
                    brightness: 1.0,
                    alpha: 1.0)
            }

            self.backgroundColor = newColor
    }
}