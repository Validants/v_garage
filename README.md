# v_garage

`v_garage` ist ein Garage-System für FiveM mit NUI, Adminverwaltung, öffentlichen Garagen, Jobgaragen, Impound-Funktion und Unterstützung für ESX sowie QBCore.

Das Script ist darauf ausgelegt, Garagen direkt ingame zu erstellen und zu verwalten, ohne Positionen dauerhaft manuell in Config-Dateien eintragen zu müssen.

## Features

- Unterstützung für ESX und QBCore
- Automatische Framework-Erkennung
- Öffentliche Garagen
- Jobgaragen mit serverseitiger Job-Prüfung
- Admin-Menü zum Erstellen und Bearbeiten von Garagen
- Separate Öffnungs-, Einpark- und Spawnpunkte
- Fahrzeugtypen:
  - normale Fahrzeuge
  - Flugzeuge und Helikopter
  - Boote
- Impound-System für Fahrzeuge mit `out`-Status
- Jobfahrzeuge pro Jobgarage
- RGB-Farben für Jobfahrzeuge
- Fahrzeug-Suche in der UI
- Blip-Option pro Garage
- Ingame Placement-Modus für Positionen
- Mehrsprachigkeit für Deutsch, Englisch und Russisch
- Key-System-Integration und nativer Lock-Fallback
- Optionale automatische Fahrzeugbilder über `screenshot-basic`

## Voraussetzungen

Benötigte Ressourcen:

```cfg
ensure oxmysql
ensure ox_lib
```

Optional empfohlen:

```cfg
ensure screenshot-basic
```

`screenshot-basic` wird nur benötigt, wenn automatische Fahrzeugbilder verwendet werden sollen. Ohne diese Resource funktioniert das Garage-System weiterhin normal.

## Installation

1. Resource in den `resources`-Ordner legen.
2. Ordnername sollte `v_garage` sein.
3. SQL ausführen:

```sql
sql/install.sql
```

4. Resource in der `server.cfg` starten:

```cfg
ensure oxmysql
ensure ox_lib
ensure v_garage
```

Wenn automatische Fahrzeugbilder genutzt werden:

```cfg
ensure screenshot-basic
ensure oxmysql
ensure ox_lib
ensure v_garage
```

## Konfiguration

Die wichtigsten Einstellungen befinden sich in:

```txt
config.lua
```

### Framework

```lua
Config.Framework = 'auto'
```

Mögliche Werte:

```lua
auto
esx
qbcore
```

### Sprache

```lua
Config.Locale = 'de'
```

Verfügbare Sprachen:

```txt
de
en
ru
```

Weitere Sprachen können in folgenden Dateien ergänzt werden:

```txt
shared/locales.lua
web/i18n.js
```

### Admin-Befehl

```lua
Config.AdminCommand = 'garageadmin'
```

Das Admin-Menü wird ingame mit folgendem Befehl geöffnet:

```txt
/garageadmin
```

### Admin-Gruppen

```lua
Config.AdminGroups = {
    esx = { 'admin', 'superadmin' },
    qbcore = { 'admin', 'god' }
}
```

## Garagentypen

Garagen können für unterschiedliche Fahrzeugarten angelegt werden.

```lua
vehicleType = 'car'
vehicleType = 'air'
vehicleType = 'boat'
```

Bedeutung:

| Typ | Beschreibung |
| --- | --- |
| `car` | normale Fahrzeuge und Motorräder |
| `air` | Helikopter und Flugzeuge |
| `boat` | Boote |

Die Garage zeigt nur Fahrzeuge an, die zum jeweiligen Fahrzeugtyp passen.

## Öffentliche Garagen

Öffentliche Garagen können von allen Spielern genutzt werden. Je nach Konfiguration werden dort alle eigenen Fahrzeuge oder nur Fahrzeuge der jeweiligen Garage angezeigt.

```lua
Config.VehicleListing = {
    onlyCurrentGarage = false,
    showOutVehicles = true
}
```

| Einstellung | Beschreibung |
| --- | --- |
| `onlyCurrentGarage` | Zeigt nur Fahrzeuge der aktuellen Garage an, wenn aktiviert |
| `showOutVehicles` | Zeigt auch ausgeparkte Fahrzeuge in der Liste an |

## Jobgaragen

Jobgaragen sind nur für Spieler mit dem passenden Job sichtbar und nutzbar. Die Prüfung findet serverseitig statt.

Beispiel:

```txt
Job: police
```

Nur Spieler mit dem Job `police` erhalten Zugriff auf diese Garage.

Admins können Jobgaragen weiterhin im Admin-Menü verwalten.

## Jobfahrzeuge

Jobgaragen können eigene Fahrzeuge besitzen. Diese Fahrzeuge werden nicht aus der normalen Spielerfahrzeug-Datenbank geladen, sondern separat gespeichert.

Tabelle:

```txt
ug_job_vehicles
```

Pro Fahrzeug können gespeichert werden:

- Spawnname
- Anzeigename
- Primärfarbe als RGB
- Sekundärfarbe als RGB

Die Fahrzeuge werden über das Admin-Menü innerhalb der jeweiligen Jobgarage erstellt, bearbeitet oder gelöscht.

## Impound

Das Impound-System zeigt Fahrzeuge an, die in der Fahrzeug-Datenbank als ausgeparkt markiert sind und nicht mehr aktiv in der Welt gefunden werden.

Konfiguration:

```lua
Config.Impound = {
    enabled = true,
    fee = 500,
    label = 'Impound',
    allowFromEveryPublicGarage = true,
    checkIntervalMinutes = 5
}
```

| Einstellung | Beschreibung |
| --- | --- |
| `enabled` | Aktiviert oder deaktiviert das Impound-System |
| `fee` | Gebühr zum Auslösen eines Fahrzeugs |
| `allowFromEveryPublicGarage` | Erlaubt das Auslösen über jede öffentliche Garage |
| `checkIntervalMinutes` | Intervall für die Prüfung aktiver Fahrzeuge |

## Fahrzeugschlüssel

Das Script kann Fahrzeugschlüssel automatisch vergeben.

Unterstützte Systeme:

- `qb-vehiclekeys`
- `qs-vehiclekeys`
- `wasabi_carlock`
- `cd_garage`
- Custom Events
- nativer Fallback

Konfiguration:

```lua
Config.VehicleKeys = {
    enabled = true,
    system = 'auto',
    giveForOwned = true,
    giveForJob = true,
    customClientEvent = nil,
    customServerEvent = nil
}
```

Zusätzlich gibt es einen integrierten Lock-Fallback:

```lua
Config.VehicleLock = {
    enabled = true,
    command = 'lockvehicle',
    key = 'U',
    distance = 8.0,
    requireKeys = true,
    useNativeFallback = true,
    flashLights = true
}
```

Standardtaste:

```txt
U
```

Command:

```txt
/lockvehicle
```

## Placement-Modus

Im Admin-Menü können Öffnungs-, Einpark- und Spawnpunkte direkt ingame gesetzt werden.

Steuerung:

| Taste | Funktion |
| --- | --- |
| `W/A/S/D` | Position verschieben |
| `Q/E` | drehen |
| `Bild hoch / Bild runter` | Höhe ändern |
| `Shift` | schneller bewegen |
| `Enter` | bestätigen |
| `Backspace` | abbrechen |

Nach dem Bestätigen wird die Position automatisch in das Admin-Menü übernommen.

## Fahrzeugbilder

Fahrzeugbilder können optional automatisch erstellt und gecached werden.

Konfiguration:

```lua
Config.VehicleImages = {
    enabled = true,
    captureOnFirstOpen = true,
    preloadModels = {},
    capturePoint = vec4(-75.17, -819.08, 326.18, 180.0),
    cameraOffset = vec3(4.6, -6.8, 2.2),
    cameraFov = 35.0
}
```

Modelle können vorab eingetragen werden:

```lua
Config.VehicleImages.preloadModels = {
    'adder',
    'sultanrs',
    'police3'
}
```

Befehl zum Vorladen:

```txt
/garagecaptureimages
```

## Datenbank

Das Script nutzt folgende eigene Tabellen:

```txt
ug_garages
ug_job_vehicles
```

Für ESX werden je nach bestehendem Schema diese Spalten in `owned_vehicles` benötigt:

```sql
ALTER TABLE `owned_vehicles` ADD COLUMN `garage` varchar(64) DEFAULT NULL;
ALTER TABLE `owned_vehicles` ADD COLUMN `stored` tinyint(1) NOT NULL DEFAULT 1;
```

QBCore nutzt in der Regel bereits passende Spalten in `player_vehicles`.

## Hinweise für bestehende Installationen

Falls bereits eine ältere Version genutzt wurde, sollte geprüft werden, ob folgende Spalten vorhanden sind:

```sql
ALTER TABLE `ug_garages` ADD COLUMN `store` longtext NULL AFTER `coords`;
ALTER TABLE `ug_garages` ADD COLUMN `vehicle_type` varchar(16) NOT NULL DEFAULT 'car' AFTER `job`;
```

Falls noch keine Werte gesetzt sind:

```sql
UPDATE `ug_garages` SET `store` = `coords` WHERE `store` IS NULL OR `store` = '';
UPDATE `ug_garages` SET `vehicle_type` = 'car' WHERE `vehicle_type` IS NULL OR `vehicle_type` = '';
```

## Server.cfg Beispiel

```cfg
ensure screenshot-basic
ensure oxmysql
ensure ox_lib
ensure v_garage
```

Ohne Fahrzeugbilder:

```cfg
ensure oxmysql
ensure ox_lib
ensure v_garage
```

## Ordnerstruktur

```txt
v_garage/
├── client/
├── server/
├── shared/
├── sql/
├── web/
├── config.lua
└── fxmanifest.lua
```

## Bekannte Hinweise

- Jobgaragen werden für Spieler ohne passenden Job nicht an den Client gesendet.
- Blips werden nur erstellt, wenn die Garage für den Spieler sichtbar ist und `blip` aktiviert wurde.
- Impound basiert auf dem Datenbankstatus und einer Prüfung der aktuell existierenden Fahrzeuge.
- Temporäre Jobfahrzeuge nutzen Kennzeichen-Präfixe als Restart-Fallback.

## Lizenz

Diese Resource ist für die Nutzung auf FiveM-Servern vorgesehen. Weitergabe, Bearbeitung oder Veröffentlichung richtet sich nach den jeweiligen Projekt- oder Serverregeln.
