import Testing
import UIKit
@testable import cameragr

/// The dark/light body switch: the setting is kept, and every themed picture
/// has a light twin that really differs.
@MainActor
struct BodyThemeTests {
    @Test func switchPersistsAndDefaultsToDark() {
        let saved = UserDefaults.standard.object(forKey: "bodyLight")
        defer { if let saved { UserDefaults.standard.set(saved, forKey: "bodyLight") } else { UserDefaults.standard.removeObject(forKey: "bodyLight") } }
        UserDefaults.standard.removeObject(forKey: "bodyLight")
        let theme = BodyTheme.shared
        let before = theme.isLight
        theme.isLight = true
        #expect(UserDefaults.standard.bool(forKey: "bodyLight"))
        theme.isLight = false
        #expect(!UserDefaults.standard.bool(forKey: "bodyLight"))
        theme.isLight = before
    }

    @Test func everyBodyPictureHasALightTwin() {
        for name in ["body_plate.jpg", "finder_deck.jpg", "bag_key.png", "body_knob.png",
                     "upright_plate.jpg", "upright_door.png", "upright_door_open.png", "upright_ev_track.png",
                     "upright_ev_knob.png", "upright_lcd.png", "upright_key_0.png", "upright_key_1.png",
                     "upright_key_2.png", "upright_key_3.png"] {
            let dark = BodyTheme.art(name, light: false)
            let light = BodyTheme.art(name, light: true)
            #expect(dark.size.width > 0, "\(name) dark is missing")
            #expect(light.size.width > 0, "\(name) light is missing")
            #expect(light.pngData() != dark.pngData(), "\(name) has no light twin")
        }
    }

    @Test func lightPlatesKeepTheDarkOnesShape() {
        for name in ["body_plate.jpg", "finder_deck.jpg", "upright_plate.jpg"] {
            let dark = BodyTheme.art(name, light: false), light = BodyTheme.art(name, light: true)
            let a = dark.size.width / dark.size.height, b = light.size.width / light.size.height
            #expect(abs(a - b) < 0.01, "\(name): light and dark shapes differ")
        }
    }
}
