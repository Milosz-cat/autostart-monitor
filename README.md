# Autostart Monitor

Skrypt PowerShell do monitorowania i ochrony punktów autostartu w systemie Windows. Wykrywa nowe wpisy w rejestrze, folderach Startup oraz Harmonogramie zadań, loguje je i (opcjonalnie) automatycznie usuwa nieautoryzowane wpisy.

## Funkcje

- **Rejestr systemowy** – monitoruje klucze `Run` i `RunOnce` w `HKLM` i `HKCU`
- **Foldery Startup** – śledzi folder Startup użytkownika i wspólny (All Users)
- **Harmonogram zadań** – wykrywa zadania z wyzwalaczami `AtStartup`, `AtLogOn`, `Boot`
- **Wykrywanie zmian** – porównuje aktualny stan z poprzednim skanem
- **Biała lista** – pozwala oznaczyć zaufane wpisy, aby nie generowały alertów
- **Logowanie** – zapisuje zdarzenia do pliku CSV oraz do Dziennika zdarzeń Windows (Event Log)
- **Tryb interaktywny lub automatyczny** – przy pierwszym uruchomieniu GUI pyta, czy nowe wpisy usuwać automatycznie, czy każdorazowo pytać użytkownika

## Wymagania

- Windows 10/11 lub Windows Server
- PowerShell 5.1 lub nowszy
- Uprawnienia administratora (zalecane, do pełnego dostępu do rejestru `HKLM` i Harmonogramu zadań)

## Instalacja

1. Pobierz skrypt `AutostartMonitor.ps1` z repozytorium.
2. Uruchom PowerShell **jako administrator**.
3. Jeśli to konieczne, zezwól na wykonywanie skryptów lokalnie:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
4. Uruchom skrypt:
   ```powershell
   .\AutostartMonitor.ps1
   ```

## Pierwsze uruchomienie

Przy pierwszym starcie pojawi się okno z opcją:

> **Enable automatic removal of new registry entries**

- **Zaznaczone** – nowe wpisy rejestru będą usuwane automatycznie bez pytania
- **Odznaczone** – każdy nowy wpis wygeneruje okno z pytaniem Tak/Nie

Wybór zapisywany jest w `settings.json` i nie będzie ponownie wyświetlany przy kolejnych uruchomieniach.

## Pliki danych

Wszystkie dane robocze skrypt przechowuje w:

```
%ProgramData%\Autostart_Monitor\
├── settings.json          # zapisana konfiguracja (tryb auto-usuwania)
├── autostart_state.json   # ostatni znany stan wszystkich wpisów autostartu
├── whitelist.json          # lista zaufanych wpisów (patrz niżej)
└── autostart_log.csv       # log wykrytych/nowych wpisów z sygnaturą czasową
```

## Biała lista (whitelist.json)

Aby oznaczyć wpis jako zaufany i pominąć go przy kolejnych skanach, dodaj go do `whitelist.json` w formacie:

```json
[
  { "Name": "OneDrive", "Command": "\"C:\\Program Files\\Microsoft OneDrive\\OneDrive.exe\" /background" }
]
```

## Automatyzacja (opcjonalnie)

Aby skrypt uruchamiał się cyklicznie, można dodać zadanie w Harmonogramie zadań, np. co godzinę:

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"C:\Sciezka\AutostartMonitor.ps1`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName "AutostartMonitor" -Action $action -Trigger $trigger -RunLevel Highest
```

## Ograniczenia

- Automatyczne usuwanie (`-Force`) obsługiwane jest obecnie tylko dla wpisów typu **Registry**. Wpisy z folderu Startup i Harmonogramu zadań są tylko raportowane.
- Do odczytu niektórych zadań w Harmonogramie mogą być wymagane uprawnienia administratora — w przeciwnym razie skrypt wypisze ostrzeżenie i pominie te wpisy.

## Licencja

MIT — używaj, modyfikuj i rozpowszechniaj dowolnie.

## Zastrzeżenie

Skrypt modyfikuje rejestr systemowy. Przed pierwszym użyciem w trybie automatycznego usuwania zaleca się:
- wykonanie kopii zapasowej rejestru,
- przetestowanie w trybie interaktywnym (bez auto-remove),
- dodanie do białej listy znanych, zaufanych programów startowych.
