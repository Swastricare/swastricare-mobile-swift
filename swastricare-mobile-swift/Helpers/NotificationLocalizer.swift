//
//  NotificationLocalizer.swift
//  swastricare-mobile-swift
//
//  Provides Hindi and Tamil translations for notification messages.
//  Falls back to English when the device language doesn't match.
//  Uses a dictionary-based approach that works without Xcode localization setup.
//

import Foundation

enum NotificationLocalizer {

    /// Supported notification languages
    enum Language: String {
        case english = "en"
        case hindi = "hi"
        case tamil = "ta"
    }

    /// Detected device language (cached)
    static let deviceLanguage: Language = {
        guard let code = Locale.current.language.languageCode?.identifier else { return .english }
        return Language(rawValue: code) ?? .english
    }()

    /// Look up a translated string by key. Returns `fallback` for English or missing keys.
    static func l(_ key: String, fallback: String, _ args: CVarArg...) -> String {
        let template: String
        if deviceLanguage == .english {
            template = fallback
        } else {
            template = translations[deviceLanguage]?[key] ?? fallback
        }
        if args.isEmpty { return template }
        return String(format: template, arguments: args)
    }

    // MARK: - Translations

    /// Hindi and Tamil translations keyed by message identifier.
    /// Format placeholders: %d = integer, %@ = string
    private static let translations: [Language: [String: String]] = [

        // ──────────────────────────── HINDI ────────────────────────────
        .hindi: [
            // Titles
            "title_goal_achieved":        "🎉 लक्ष्य पूरा!",
            "title_amazing_work":         "⭐ शानदार!",
            "title_well_done":            "🏆 बहुत बढ़िया!",
            "title_you_did_it":           "💪 कर दिखाया!",
            "title_great_start":          "☀️ बढ़िया शुरुआत!",
            "title_excellent_progress":   "🌟 शानदार प्रगति!",
            "title_almost_there":         "🎯 बस थोड़ा और!",
            "title_final_push":           "💧 आखिरी प्रयास",
            "title_morning_hydration":    "☕ सुबह का पानी",
            "title_rise_hydrate":         "🌅 उठो और पानी पियो",
            "title_morning_boost":        "💪 सुबह की ताज़गी",
            "title_hydration_check":      "📊 पानी की जांच",
            "title_afternoon_reminder":   "☕ दोपहर का रिमाइंडर",
            "title_stay_hydrated":        "💧 हाइड्रेटेड रहें",
            "title_evening_hydration":    "🌆 शाम का पानी",
            "title_keep_it_up":           "⭐ जारी रखें",
            "title_almost_done":          "💧 लगभग हो गया",
            "title_last_call":            "🌙 आखिरी मौका",
            "title_lets_get_started":     "⚠️ शुरू करें",
            "title_hydration_alert":      "🚨 पानी की चेतावनी",
            "title_urgent_reminder":      "⏰ ज़रूरी रिमाइंडर",
            "title_final_reminder":       "💧 आखिरी रिमाइंडर",
            "title_hot_day_alert":        "🌡️ गर्मी की चेतावनी",
            "title_beat_the_heat":        "☀️ गर्मी से बचें",
            "title_hydration_boost":      "🥵 ज़्यादा पानी पियें",
            "title_post_workout":         "🏃‍♂️ कसरत के बाद",
            "title_recovery_time":        "💪 रिकवरी का समय",
            "title_fuel_your_body":       "🎯 शरीर को ऊर्जा दें",
            "title_pattern_alert":        "📊 पैटर्न अलर्ट",
            "title_right_on_schedule":    "🎯 सही समय पर",
            "title_your_hydration_time":  "💧 आपके पानी का समय",
            "title_fill_the_gap":         "💡 इस समय पानी पियें",
            "title_streak_at_risk":       "🔥 स्ट्रीक ख़तरे में!",
            "title_good_morning":         "🌅 सुप्रभात!",

            // Bodies
            "body_goal_reached":          "आपने अपने %dml का लक्ष्य पूरा किया! बहुत बढ़िया!",
            "body_goal_body_thanks":      "शानदार! आपने अपना हाइड्रेशन लक्ष्य पूरा किया। आपका शरीर धन्यवाद कहता है!",
            "body_goal_complete":         "लक्ष्य पूरा! आप स्वस्थ और हाइड्रेटेड हैं।",
            "body_streak_7":             "🔥 %d दिन का स्ट्रीक! आप हाइड्रेशन चैंपियन हैं!",
            "body_streak_3":             "%d दिन लगातार! स्ट्रीक जारी रखें!",
            "body_ahead_morning":         "आप अपने लक्ष्य के %d%% पर हैं! जारी रखें!",
            "body_ahead_afternoon":       "आप %d%% पर हैं। बस %dml और!",
            "body_ahead_evening":         "बस %dml और! आप कर सकते हैं!",
            "body_ahead_night":           "आप बहुत करीब हैं! %dml और पी लें।",
            "body_morning_start":         "सुप्रभात! एक गिलास पानी से दिन शुरू करें 💧",
            "body_morning_overnight":     "रात में शरीर का पानी कम होता है। अभी पी लें!",
            "body_morning_metabolism":    "एक गिलास पानी से मेटाबॉलिज्म बढ़ाएं!",
            "body_afternoon_progress":    "आप अपने लक्ष्य के %d%% पर हैं! जारी रखें 💪",
            "body_afternoon_slump":       "दोपहर की थकान? एक गिलास पानी मदद करेगा!",
            "body_afternoon_remaining":   "%dml बाकी है। बहुत अच्छा चल रहा है!",
            "body_evening_remaining":     "शाम का पानी न भूलें! %dml बाकी है।",
            "body_evening_finish":        "आप %d%% पर हैं। मज़बूती से खत्म करें!",
            "body_evening_almost":        "बस %dml और! लक्ष्य पूरा करें!",
            "body_night_last":            "सोने से पहले एक आखिरी गिलास। %dml बाकी!",
            "body_behind_morning":        "हाइड्रेट होना न भूलें! पानी से दिन शुरू करें।",
            "body_behind_afternoon":      "आप %d%% पर हैं। अभी पानी पी लें।",
            "body_behind_evening":        "अभी भी %dml बाकी है। लक्ष्य पूरा करें!",
            "body_behind_night":          "आज पीछे हैं। सोने से पहले %dml पी लें।",
            "body_hot_exercise":          "कसरत के बाद %d°C में, ज़्यादा पानी चाहिए! %dml बाकी।",
            "body_hot_day":               "बाहर %d°C है! शरीर को ज़्यादा पानी चाहिए। %dml बाकी।",
            "body_hot_cool":              "ठंडे और हाइड्रेटेड रहें! %d°C है। अभी पानी पियें।",
            "body_hot_extra":             "गर्मी में ज़्यादा पानी चाहिए। %dml बाकी।",
            "body_post_workout":          "बढ़िया %d मिनट कसरत! अब पानी पियें। %dml बाकी।",
            "body_recovery":             "कसरत के बाद पानी भरें! %dml बाकी।",
            "body_fuel":                  "कसरत से पानी कम होता है। पी लें! %dml बाकी।",
            "body_pattern_high":          "आप आमतौर पर इस समय पानी पीते हैं! %dml बाकी।",
            "body_pattern_schedule":      "यह आपके पानी पीने का सही समय है!",
            "body_pattern_time":          "आपके पैटर्न के अनुसार, अभी पानी पीने का बढ़िया समय है!",
            "body_pattern_gap":           "इस समय आप कम पानी पीते हैं — पूरा करने का मौका! %dml बाकी।",
            "body_streak_risk":           "आपका %d दिन का स्ट्रीक ख़तरे में है! बस %dml और पियें।",
            "body_fresh_morning":         "नया दिन, नया लक्ष्य! एक गिलास पानी से शुरू करें। 💧",
            "body_fresh_reminder":        "पानी पीने का समय! हाइड्रेटेड रह कर स्वस्थ रहें। 💧",
        ],

        // ──────────────────────────── TAMIL ────────────────────────────
        .tamil: [
            // Titles
            "title_goal_achieved":        "🎉 இலக்கு அடைந்தீர்!",
            "title_amazing_work":         "⭐ அருமை!",
            "title_well_done":            "🏆 நல்லா செஞ்சீங்க!",
            "title_you_did_it":           "💪 செய்து காட்டினீங்க!",
            "title_great_start":          "☀️ நல்ல தொடக்கம்!",
            "title_excellent_progress":   "🌟 சிறப்பான முன்னேற்றம்!",
            "title_almost_there":         "🎯 கிட்டத்தட்ட முடிஞ்சிடுச்சு!",
            "title_final_push":           "💧 கடைசி முயற்சி",
            "title_morning_hydration":    "☕ காலை தண்ணீர்",
            "title_rise_hydrate":         "🌅 எழுந்து தண்ணீர் குடிங்க",
            "title_morning_boost":        "💪 காலை புத்துணர்ச்சி",
            "title_hydration_check":      "📊 தண்ணீர் நிலை",
            "title_afternoon_reminder":   "☕ மதியம் நினைவூட்டல்",
            "title_stay_hydrated":        "💧 தண்ணீர் குடிங்க",
            "title_evening_hydration":    "🌆 மாலை தண்ணீர்",
            "title_keep_it_up":           "⭐ தொடருங்க",
            "title_almost_done":          "💧 கிட்டத்தட்ட முடிஞ்சிடுச்சு",
            "title_last_call":            "🌙 கடைசி வாய்ப்பு",
            "title_lets_get_started":     "⚠️ ஆரம்பிக்கலாம்",
            "title_hydration_alert":      "🚨 தண்ணீர் எச்சரிக்கை",
            "title_urgent_reminder":      "⏰ அவசர நினைவூட்டல்",
            "title_final_reminder":       "💧 கடைசி நினைவூட்டல்",
            "title_hot_day_alert":        "🌡️ வெப்ப எச்சரிக்கை",
            "title_beat_the_heat":        "☀️ வெப்பத்தை சமாளிங்க",
            "title_hydration_boost":      "🥵 அதிகம் குடிங்க",
            "title_post_workout":         "🏃‍♂️ உடற்பயிற்சிக்கு பிறகு",
            "title_recovery_time":        "💪 மீட்பு நேரம்",
            "title_fuel_your_body":       "🎯 உடலுக்கு சக்தி",
            "title_pattern_alert":        "📊 பேட்டர்ன் அலர்ட்",
            "title_right_on_schedule":    "🎯 சரியான நேரம்",
            "title_your_hydration_time":  "💧 உங்க தண்ணீர் நேரம்",
            "title_fill_the_gap":         "💡 இப்போ குடிங்க",
            "title_streak_at_risk":       "🔥 ஸ்ட்ரீக் ஆபத்தில்!",
            "title_good_morning":         "🌅 காலை வணக்கம்!",

            // Bodies
            "body_goal_reached":          "உங்க %dml இலக்கை அடைந்தீங்க! மிக அருமை!",
            "body_goal_body_thanks":      "அருமை! ஹைட்ரேஷன் இலக்கை எட்டிட்டீங்க. உங்க உடல் நன்றி சொல்கிறது!",
            "body_goal_complete":         "இலக்கு நிறைவேறியது! ஆரோக்கியமா இருக்கீங்க.",
            "body_streak_7":             "🔥 %d நாள் ஸ்ட்ரீக்! நீங்க ஹைட்ரேஷன் சாம்பியன்!",
            "body_streak_3":             "%d நாள் தொடர்ச்சியா! ஸ்ட்ரீக் தொடருங்க!",
            "body_ahead_morning":         "இலக்கின் %d%% முடிஞ்சிடுச்சு! தொடருங்க!",
            "body_ahead_afternoon":       "%d%% முடிஞ்சிடுச்சு. இன்னும் %dml தான்!",
            "body_ahead_evening":         "இன்னும் %dml தான்! உங்களால் முடியும்!",
            "body_ahead_night":           "கிட்டத்தட்ட முடிஞ்சிடுச்சு! %dml குடிங்க.",
            "body_morning_start":         "காலை வணக்கம்! ஒரு டம்ளர் தண்ணீர் குடிங்க 💧",
            "body_morning_overnight":     "இரவில் உடல் நீர் குறையும். இப்போ குடிங்க!",
            "body_morning_metabolism":    "தண்ணீர் குடிச்சு மெட்டபாலிசம் அதிகரிங்க!",
            "body_afternoon_progress":    "இலக்கின் %d%% முடிஞ்சிடுச்சு! தொடருங்க 💪",
            "body_afternoon_slump":       "மதியம் சோர்வா? ஒரு டம்ளர் தண்ணீர் உதவும்!",
            "body_afternoon_remaining":   "%dml மீதமிருக்கு. நல்லா போகுது!",
            "body_evening_remaining":     "மாலை தண்ணீர் மறக்காதீங்க! %dml மீதம்.",
            "body_evening_finish":        "%d%% ஆச்சு. வலுவா முடிங்க!",
            "body_evening_almost":        "இன்னும் %dml தான்! இலக்கை அடையுங்க!",
            "body_night_last":            "தூங்குவதற்கு முன் கடைசி டம்ளர். %dml மீதம்!",
            "body_behind_morning":        "தண்ணீர் குடிக்க மறக்காதீங்க! தண்ணீரோட தொடங்குங்க.",
            "body_behind_afternoon":      "%d%% தான் குடிச்சிருக்கீங்க. இப்போ குடிங்க.",
            "body_behind_evening":        "இன்னும் %dml வேணும். இலக்கை அடையுங்க!",
            "body_behind_night":          "இன்று பின்தங்கிட்டீங்க. தூங்குமுன் %dml குடிங்க.",
            "body_hot_exercise":          "உடற்பயிற்சிக்கு பிறகு %d°C-ல், அதிகம் தண்ணீர் வேணும்! %dml மீதம்.",
            "body_hot_day":               "வெளியே %d°C! உடலுக்கு அதிக தண்ணீர் தேவை. %dml மீதம்.",
            "body_hot_cool":              "குளிர்ச்சியா இருங்க! %d°C இருக்கு. இப்போ குடிங்க.",
            "body_hot_extra":             "வெப்பத்தில் அதிக தண்ணீர் தேவை. %dml மீதம்.",
            "body_post_workout":          "அருமையான %d நிமிட பயிற்சி! இப்போ குடிங்க. %dml மீதம்.",
            "body_recovery":             "பயிற்சிக்கு பிறகு நீர் நிரப்புங்க! %dml மீதம்.",
            "body_fuel":                  "பயிற்சி நீரை குறைக்கும். குடிங்க! %dml மீதம்.",
            "body_pattern_high":          "நீங்க வழக்கமா இந்த நேரத்தில் குடிப்பீங்க! %dml மீதம்.",
            "body_pattern_schedule":      "இது உங்க தண்ணீர் குடிக்கும் நேரம்!",
            "body_pattern_time":          "உங்க பேட்டர்ன் படி, இப்போ குடிக்க நல்ல நேரம்!",
            "body_pattern_gap":           "இந்த நேரத்தில் குறைவா குடிப்பீங்க — நிரப்ப நல்ல வாய்ப்பு! %dml மீதம்.",
            "body_streak_risk":           "உங்க %d நாள் ஸ்ட்ரீக் ஆபத்தில்! இன்னும் %dml குடிங்க.",
            "body_fresh_morning":         "புது நாள், புது இலக்கு! ஒரு டம்ளர் தண்ணீரோட தொடங்குங்க. 💧",
            "body_fresh_reminder":        "தண்ணீர் குடிக்கும் நேரம்! ஹைட்ரேட்டா இருந்தா ஆரோக்கியம். 💧",
        ]
    ]
}
