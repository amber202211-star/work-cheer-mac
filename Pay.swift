import Foundation

struct WorkSettings: Codable {
    var salary: Double = 12000
    var weekdays: Set<Int> = [2, 3, 4, 5, 6] // Calendar: Sunday = 1
    var startMinute: Int = 540
    var endMinute: Int = 1080
    var valid: Bool {
        salary.isFinite && salary > 0 && salary <= 10000000 && !weekdays.isEmpty &&
        weekdays.isSubset(of: Set(1...7)) && (0..<1440).contains(startMinute) &&
        (0..<1440).contains(endMinute) && startMinute != endMinute
    }
}

struct Payroll {
    var settings: WorkSettings
    var calendar = Calendar.current
    func shift(_ date: Date) -> (start: Date, end: Date) {
        let start = calendar.date(bySettingHour: settings.startMinute / 60, minute: settings.startMinute % 60, second: 0, of: date)!
        var end = calendar.date(bySettingHour: settings.endMinute / 60, minute: settings.endMinute % 60, second: 0, of: date)!
        if end <= start { end = calendar.date(byAdding: .day, value: 1, to: end)! }
        return (start, end)
    }
    func isWorkday(_ date: Date) -> Bool { settings.weekdays.contains(calendar.component(.weekday, from: date)) }
    func workdays(_ date: Date) -> Int {
        let start = calendar.dateInterval(of: .month, for: date)!.start
        return calendar.range(of: .day, in: .month, for: date)!.filter {
            isWorkday(calendar.date(byAdding: .day, value: $0 - 1, to: start)!)
        }.count
    }
    func seconds(_ date: Date, now: Date) -> Double {
        guard isWorkday(date) else { return 0 }
        let s = shift(date)
        return max(0, min(now, s.end).timeIntervalSince(s.start))
    }
    func rate(_ date: Date) -> Double {
        let s = shift(date)
        return settings.salary / Double(workdays(date)) / s.end.timeIntervalSince(s.start)
    }
    func earnings(_ date: Date, now: Date) -> Double { seconds(date, now: now) * rate(date) }
    func monthTotal(_ now: Date) -> Double {
        let start = calendar.dateInterval(of: .month, for: now)!.start
        return (0..<calendar.component(.day, from: now)).reduce(0) { sum, index in
            sum + earnings(calendar.date(byAdding: .day, value: index, to: start)!, now: now)
        }
    }
    func nextShift(_ now: Date) -> (start: Date, end: Date) {
        for offset in -1...7 {
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            let s = shift(date)
            if isWorkday(date) && s.end > now { return s }
        }
        return shift(now)
    }
    static func clock(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }
    static func selfTest() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
        }
        var p = Payroll(settings: WorkSettings(), calendar: cal)
        precondition(p.seconds(date(5, 0), now: date(5, 10, 30)) == 5400)
        precondition(p.seconds(date(5, 0), now: date(5, 8)) == 0)
        precondition(p.seconds(date(5, 0), now: date(5, 20)) == 32400)
        precondition(p.seconds(date(7, 0), now: date(7, 12)) == 0)
        precondition(abs(p.monthTotal(date(30, 23)) - 12000) < 0.001)
        precondition(cal.component(.day, from: p.nextShift(date(7, 12)).start) == 9)
        p.settings.startMinute = 1320; p.settings.endMinute = 360
        precondition(p.seconds(date(5, 0), now: date(6, 2)) == 14400)
        print("PASS: scheduled earnings, end cap, weekends, monthly total, overnight.")
    }
}
