import SwiftUI

enum Palette {
    static let accent = Color(red: 177 / 255, green: 239 / 255, blue: 135 / 255)
    static let ink = Color(red: 32 / 255, green: 49 / 255, blue: 26 / 255)
    static func canvas(_ scheme: ColorScheme) -> Color { scheme == .dark ? Color(red: 16 / 255, green: 19 / 255, blue: 18 / 255) : Color(red: 243 / 255, green: 245 / 255, blue: 240 / 255) }
    static func card(_ scheme: ColorScheme) -> Color { scheme == .dark ? Color(red: 25 / 255, green: 29 / 255, blue: 27 / 255) : .white }
    static func rail(_ scheme: ColorScheme) -> Color { scheme == .dark ? Color(red: 43 / 255, green: 50 / 255, blue: 46 / 255) : Color.black.opacity(0.12) }
}

struct Panel<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card(scheme), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.rail(scheme), lineWidth: 1))
    }
}

struct AccentButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 18).frame(maxWidth: .infinity, minHeight: 48)
            .background(Palette.accent.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 9))
            .foregroundStyle(Palette.ink)
    }
}

func fileBytes(_ size: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: size, countStyle: .decimal)
}

enum Language {
    static func text(_ source: String, _ language: String) -> String { language == "pl" ? polish[source] ?? source : source }
    private static let polish: [String: String] = [
        "Less space. More quality.": "Mniej miejsca. Więcej jakości.",
        "SMALLER FILES. SAME MOMENTS.": "MNIEJSZE PLIKI. TE SAME CHWILE.",
        "Make room for more.": "Zrób miejsce na więcej.",
        "Compress your MP4 videos. Keep what matters.": "Kompresuj filmy MP4. Zachowaj to, co ważne.",
        "NEW COMPRESSION": "NOWA KOMPRESJA", "Add your files": "Dodaj swoje pliki",
        "Choose local files": "Wybierz pliki z urządzenia", "MP4 videos from Files": "Filmy MP4 z aplikacji Pliki",
        "Choose MP4 files": "Wybierz pliki MP4", "Adding files…": "Dodawanie plików…",
        "Set your compression": "Ustaw kompresję", "Compression %": "Kompresja %", "Target MB": "Docelowe MB",
        "Reduce file size by": "Zmniejsz rozmiar pliku o", "Higher quality": "Wyższa jakość", "Smaller file": "Mniejszy plik",
        "Maximum output size · MB": "Maksymalny rozmiar wyniku · MB", "Per video · 1 MB = 1,000,000 bytes": "Na film · 1 MB = 1 000 000 bajtów",
        "Save defaults": "Zapisz domyślne", "Compress files": "Kompresuj pliki", "Cancel": "Anuluj",
        "EVERYTHING IN ONE PLACE": "WSZYSTKO W JEDNYM MIEJSCU", "Your compressions": "Twoje kompresje",
        "All": "Wszystkie", "Active": "Aktywne", "Completed": "Ukończone", "Clear": "Wyczyść",
        "Your files will appear here": "Tutaj pojawią się Twoje pliki",
        "Add MP4 files and choose your target size.": "Dodaj pliki MP4 i wybierz docelowy rozmiar.",
        "Everything stays on your device.": "Wszystko pozostaje na Twoim urządzeniu.",
        "Reading…": "Odczytywanie…", "Ready": "Gotowe", "Compressing…": "Kompresowanie…", "Complete": "Ukończono",
        "Failed": "Błąd", "Cancelled": "Anulowano", "Adjusting size…": "Dostosowywanie rozmiaru…",
        "Share / Save": "Udostępnij / Zapisz", "Preview": "Podgląd", "Remove": "Usuń", "Options": "Opcje",
        "Output target": "Docelowy rozmiar", "Done": "Gotowe", "Settings": "Ustawienia", "Appearance": "Wygląd",
        "Dark": "Ciemny", "Light": "Jasny", "System": "Systemowy", "Defaults saved": "Zapisano ustawienia",
        "Keep this app open while compressing.": "Pozostaw aplikację otwartą podczas kompresji.",
        "Only MP4 videos are supported.": "Obsługiwane są tylko filmy MP4.",
        "This video could not be read.": "Nie udało się odczytać filmu.",
        "Choose a target smaller than the original file.": "Wybierz rozmiar mniejszy od oryginału.",
        "This target is too small. Increase the output size.": "Ten limit jest za mały. Zwiększ rozmiar wyniku.",
        "Enter a valid output size.": "Wpisz prawidłowy rozmiar wyniku.",
        "Compression failed. Try a larger output size.": "Kompresja nie powiodła się. Wybierz większy rozmiar.",
        "The compressed video could not be verified.": "Nie udało się zweryfikować skompresowanego filmu.",
        "The output file is no longer available.": "Plik wynikowy nie jest już dostępny.",
        "Not enough free space on this device.": "Za mało wolnego miejsca na urządzeniu.",
        "This file could not be processed. Try downloading it to Files first.": "Nie udało się przetworzyć pliku. Najpierw pobierz go do aplikacji Pliki.",
        "No files in this view.": "Brak plików w tym widoku."
    ]
}
