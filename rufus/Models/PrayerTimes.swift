import Foundation
import SwiftData

struct PrayerTime: Codable {
    let fajr: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String
    let sunrise: String
    let sunset: String
    let imsak: String
    let midnight: String
    let firstthird: String
    let lastthird: String

    enum CodingKeys: String, CodingKey {
        case fajr = "Fajr"
        case dhuhr = "Dhuhr"
        case asr = "Asr"
        case maghrib = "Maghrib"
        case isha = "Isha"
        case sunrise = "Sunrise"
        case sunset = "Sunset"
        case imsak = "Imsak"
        case midnight = "Midnight"
        case firstthird = "Firstthird"
        case lastthird = "Lastthird"
    }
}

struct PrayerTimingsResponse: Codable {
    let code: Int
    let status: String
    let data: PrayerData
}

struct PrayerData: Codable {
    let timings: PrayerTime
    let date: PrayerDate
    let meta: PrayerMeta
}

struct PrayerDate: Codable {
    let readable: String
    let timestamp: String
    let hijri: HijriDate
    let gregorian: GregorianDate
}

struct HijriDate: Codable {
    let date: String
    let format: String
    let day: String
    let weekday: WeekdayData
    let month: MonthData
    let year: String
    let designation: DesignationData
    let holidays: [String]?
}

struct GregorianDate: Codable {
    let date: String
    let format: String
    let day: String
    let weekday: WeekdayData
    let month: MonthData
    let year: String
    let designation: DesignationData
}

struct WeekdayData: Codable {
    let en: String
    let ar: String
}

struct MonthData: Codable {
    let number: Int
    let en: String
    let ar: String
}

struct DesignationData: Codable {
    let abbreviated: String
    let expanded: String
}

struct PrayerMeta: Codable {
    let latitude: Double
    let longitude: Double
    let timezone: String
    let method: PrayerMethod
    let latitudeAdjustmentMethod: String
    let midnightMode: String
    let school: String
    let offset: [String: Int]
}

struct PrayerMethod: Codable {
    let id: Int
    let name: String
    let params: PrayerParams
    let location: PrayerLocation
}

struct PrayerParams: Codable {
    let fajr: Double
    let isha: Double
    let maghrib: Double?
    let midnight: String?
}

struct PrayerLocation: Codable {
    let latitude: Double
    let longitude: Double
}

@Model
class UserLocation {
    var latitude: Double
    var longitude: Double
    var city: String?
    var country: String?
    var calculationMethod: String
    var lastLocationUpdate: Date

    init(latitude: Double, longitude: Double, city: String? = nil, country: String? = nil, calculationMethod: String = "KARACHI") {
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.country = country
        self.calculationMethod = calculationMethod
        self.lastLocationUpdate = Date()
    }
}

@Model
class DailyPrayerTimes {
    var date: Date
    var fajr: String
    var dhuhr: String
    var asr: String
    var maghrib: String
    var isha: String
    var sunrise: String
    var sunset: String
    var calculationMethod: String
    var latitude: Double
    var longitude: Double

    init(date: Date, timings: PrayerTime, method: String, latitude: Double, longitude: Double) {
        self.date = date
        self.fajr = timings.fajr
        self.dhuhr = timings.dhuhr
        self.asr = timings.asr
        self.maghrib = timings.maghrib
        self.isha = timings.isha
        self.sunrise = timings.sunrise
        self.sunset = timings.sunset
        self.calculationMethod = method
        self.latitude = latitude
        self.longitude = longitude
    }
}