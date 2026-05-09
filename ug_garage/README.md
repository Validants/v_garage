# ug_garage

Universal ESX/QBCore garage with NUI administration.

## New in this version

- Vehicle cards now use vehicle images instead of huge text blocks.
- Vehicle details are still available under "Mehr Informationen".
- Automatic client-side image cache per vehicle model.
- Job garages are only visible and usable for players with the matching job.
- Admin menu still lists all garages for management.

## Vehicle images

The resource can automatically create vehicle screenshots when a model appears in a garage for the first time.

For automatic screenshots, install and start `screenshot-basic` before this resource:

```cfg
ensure screenshot-basic
ensure oxmysql
ensure ox_lib
ensure ug_garage
```

Images are cached client-side. If `screenshot-basic` is not running, the UI shows a clean placeholder instead of breaking.

You can preload models in `config.lua`:

```lua
Config.VehicleImages.preloadModels = {
    'adder',
    'sultanrs',
    'police3'
}
```

Or run ingame:

```txt
/garagecaptureimages
```

This captures all models listed in `Config.VehicleImages.preloadModels`.

## Job garages

Job garages are filtered server-side. Players without the required job do not receive the garage from the server, so they do not see the blip or markers and cannot use it.

If you want admins to see job garages in normal gameplay, set:

```lua
Config.AdminSeeJobGaragesInWorld = true
```

The admin menu still shows all garages regardless of this setting.

## Sims-Placement-Modus

Im Admin-Menü gibt es bei Öffnungspunkt, Einparkpunkt und Auspark-/Spawnpunkt jetzt den Button **Sims-Modus**.

Steuerung im Placement-Modus:

- `W/A/S/D` verschieben
- `Q/E` drehen
- `Bild hoch / Bild runter` Höhe ändern
- `Shift` schneller bewegen
- `Enter` bestätigen
- `Backspace` abbrechen

Nach dem Bestätigen öffnet sich die Admin-NUI wieder automatisch und die neue Position wird übernommen.


## Fahrzeugliste leer?
Standardmäßig zeigt die Garage jetzt alle eigenen Fahrzeuge an, auch wenn sie in der Datenbank noch einer anderen Garage zugewiesen sind. Das ist wichtig für neu ingame erstellte Garagen.

Wenn du pro Garage streng filtern willst, setze in `config.lua`:

```lua
Config.VehicleListing.onlyCurrentGarage = true
```

## v7: Jobfahrzeuge mit RGB-Farben

Jobgaragen können jetzt eigene Fahrzeuge enthalten. Diese Fahrzeuge sind keine Privatfahrzeuge aus `owned_vehicles`/`player_vehicles`, sondern werden pro Jobgarage in `ug_job_vehicles` gespeichert.

### Admin-NUI

Im Admin-Menü gibt es einen neuen Bereich **Jobfahrzeuge**:

- Garage-ID eintragen oder über **Bearbeiten** bei einer vorhandenen Jobgarage automatisch übernehmen
- Spawnname eintragen, z. B. `police3`, `ambulance`, `sultanrs`
- Anzeigename eintragen
- Primärfarbe per RGB setzen
- Sekundärfarbe per RGB setzen

Die Farben werden in der Garage als Farbpunkte und RGB-Werte angezeigt. Beim Ausparken werden die RGB-Farben direkt auf das Fahrzeug gesetzt.

### Zugriff

Jobgaragen bleiben strikt serverseitig geschützt:

- nur Spieler mit passendem Job erhalten die Garage vom Server
- nur Spieler mit passendem Job sehen Blip/Marker
- nur Spieler mit passendem Job können die Jobfahrzeuge ausparken

### SQL

Neue Tabelle:

```sql
CREATE TABLE IF NOT EXISTS `ug_job_vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `garage_id` varchar(64) NOT NULL,
  `model` varchar(80) NOT NULL,
  `label` varchar(100) NOT NULL,
  `primary_r` tinyint(3) unsigned NOT NULL DEFAULT 255,
  `primary_g` tinyint(3) unsigned NOT NULL DEFAULT 255,
  `primary_b` tinyint(3) unsigned NOT NULL DEFAULT 255,
  `secondary_r` tinyint(3) unsigned NOT NULL DEFAULT 255,
  `secondary_g` tinyint(3) unsigned NOT NULL DEFAULT 255,
  `secondary_b` tinyint(3) unsigned NOT NULL DEFAULT 255,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `garage_id` (`garage_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Die Resource erstellt die Tabelle beim Start automatisch, wenn `oxmysql` läuft.

## Admin-Flow für Jobfahrzeuge

Jobfahrzeuge werden nicht mehr global über eine separate Garage-ID gepflegt. Der Ablauf ist jetzt:

1. `/garageadmin` öffnen
2. Bei einer Jobgarage auf **Bearbeiten** klicken
3. Darunter erscheint **Fahrzeugliste**
4. Im Bereich **Fahrzeug erstellen** Spawnname, Anzeigename und RGB-Farben eintragen
5. **Fahrzeug erstellen** drücken

Die Fahrzeugliste zeigt immer nur die Fahrzeuge der aktuell bearbeiteten Jobgarage.


## Fahrzeugschlüssel / Abschließen

Jobfahrzeuge bekommen beim Ausparken jetzt automatisch ein temporäres Kennzeichen und Schlüssel. Unterstützt werden automatisch:

- `qb-vehiclekeys`
- `qs-vehiclekeys`
- `wasabi_carlock`
- `cd_garage`

Konfiguration in `config.lua`:

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

Wenn du ein anderes Key-System nutzt, trage dort dein eigenes Client- oder Server-Event ein.
Das Client-Event bekommt: `vehicle, plate, model, netId, isJobVehicle`.
Das Server-Event bekommt: `plate, model, netId, isJobVehicle`.

## Version 10: Jobfahrzeug-Schlüssel + neues UI

### Jobfahrzeuge abschließen
Jobfahrzeuge bekommen beim Ausparken jetzt automatisch einen lokalen Schlüssel. Dadurch können sie auch dann abgeschlossen und wieder geöffnet werden, wenn dein externes Key-System temporäre Jobfahrzeuge nicht sauber erkennt.

Standard-Taste:

```txt
U
```

Command:

```txt
/lockvehicle
```

Config:

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

Das Script prüft zuerst lokal vergebene Schlüssel. Bei normalen Spielerfahrzeugen wird zusätzlich serverseitig geprüft, ob das Kennzeichen dem Spieler gehört.

### Modernisiertes UI
Das komplette NUI wurde optisch überarbeitet:

- moderne Fahrzeugkarten
- größere Fahrzeugbilder
- klare Status-Badges
- bessere Suchleiste
- kompaktere Fahrzeugdaten
- Details erst unter „Mehr Informationen“
- RGB-Farben sichtbar als Farbpillen
- modernere Administration für Garagen und Jobfahrzeuge



## v11 - UI ohne Hintergrundeffekte

- Fullscreen-Dim/Blur/Gradient entfernt.
- Es wird nur noch das eigentliche Garage-UI über dem Spiel angezeigt.
- Panel-Blur entfernt, damit der Hintergrund nicht mehr optisch beeinflusst wird.


## v12 - Jobfahrzeuge einparken

Jobfahrzeuge, die aus einer Jobgarage ausgeparkt wurden, können jetzt wieder am Einparkpunkt derselben Jobgarage eingeparkt werden.

Technik:
- Beim Ausparken registriert der Client das Jobfahrzeug serverseitig mit Kennzeichen, Garage-ID und Jobfahrzeug-ID.
- Beim Einparken prüft der Server, ob das Fahrzeug wirklich aus dieser Jobgarage stammt.
- Danach wird das Fahrzeug gelöscht und steht in der Jobfahrzeugliste wieder normal zur Verfügung.

## v13 - Adminpanel-Reiter für Jobgaragen

Neu:

- Adminpanel hat jetzt getrennte Reiter für **Öffentliche Garagen** und **Jobgaragen**.
- Jobgaragen haben einen eigenen Workspace:
  - `Jobgarage öffnen` → eigene Ansicht für diese Garage
  - Reiter **Garage bearbeiten**
  - Reiter **Fahrzeuge**
- In der Fahrzeugliste einer Jobgarage kannst du Fahrzeuge jetzt:
  - erstellen
  - bearbeiten
  - löschen
- RGB-Primär- und Sekundärfarben bleiben weiterhin pro Jobfahrzeug editierbar.

Empfohlener Ablauf:

```txt
Garage Administration → Jobgaragen → police öffnen → Fahrzeuge → Fahrzeug erstellen/bearbeiten
```

## v14: Garagentypen + UI Refresh

Garagen können jetzt einen Fahrzeugtyp haben:

- `car` = normale Fahrzeuge und Motorräder
- `air` = Helikopter und Flugzeuge
- `boat` = Boote

Im Adminpanel gibt es dafür beim Erstellen/Bearbeiten einer Garage das Feld **Fahrzeugtyp**. Die Garage zeigt dann nur passende Fahrzeuge an. Beim Einparken wird ebenfalls geprüft, ob der Fahrzeugtyp zur Garage passt.

Der Einparkmarker wird jetzt nur angezeigt, wenn der Spieler in einem Fahrzeug sitzt. Ohne Fahrzeug bleibt der Einparkpunkt unsichtbar.

Bestehende Installationen bekommen automatisch die neue Spalte:

```sql
ALTER TABLE `ug_garages` ADD COLUMN `vehicle_type` varchar(16) NOT NULL DEFAULT 'car' AFTER `job`;
UPDATE `ug_garages` SET `vehicle_type` = 'car' WHERE `vehicle_type` IS NULL OR `vehicle_type` = '';
```

Das NUI wurde in Richtung Showroom/Grid-Design umgebaut: große Headline, Statistikleiste, Suche oben und cleanere Fahrzeugkarten mit Neon-Akzenten.


## v17: Jobfahrzeug-Restart-Fix ohne aktive DB-Tabelle

Die Tabelle `ug_active_job_vehicles` wird nicht mehr genutzt. Jobfahrzeuge werden jetzt eleganter erkannt über:

1. **Entity-Statebags** direkt am Fahrzeug, solange das Entity sauber existiert.
2. **Job-Kennzeichen-Präfix** als Fallback nach einem Restart der Garage-Resource.

Dadurch bleiben Jobfahrzeuge nach einem Resource-Restart abschließbar und einparkbar, ohne dass jedes aktive Jobfahrzeug in einer separaten Datenbanktabelle gespeichert werden muss.

Wichtig: Nutze pro Job ein eindeutiges Kennzeichen-Präfix in `config.lua`:

```lua
Config.JobVehicles = {
    platePrefix = 'JOB',
    platePrefixes = {
        police = 'LSPD',
        ambulance = 'EMS',
        mechanic = 'MECH'
    },
    garagePlatePrefixes = {}
}
```

Wenn du von v16 kommst, kannst du die alte Tabelle optional löschen:

```sql
DROP TABLE IF EXISTS `ug_active_job_vehicles`;
```

Das ist optional. Die Resource verwendet sie nicht mehr.

Hinweis: Ohne `garagePlatePrefixes` wird nach einem Restart über das Job-Präfix geprüft. Das reicht für die meisten Server. Wenn du mehrere Garagen für denselben Job hast und erzwingen willst, dass ein Fahrzeug nur in genau diese Garage zurück kann, trage pro Garage ein eigenes Präfix ein, zum Beispiel `police_city = 'PD1'` und `police_sandy = 'PD2'`.

## v18 Änderungen

- Jobfahrzeuge können nach Resource-Restart wieder zuverlässiger eingeparkt werden.
  - Live-Erkennung: Entity-Statebag.
  - Fallback: Job-/Garage-Kennzeichenpräfix.
  - Wenn der Statebag nach Restart noch existiert, aber nicht sauber zur Garage passt, darf jetzt der Plate-Fallback entscheiden.
- Neuer Impound-Reiter in öffentlichen Garagen.
  - Zeigt Spielerfahrzeuge an, die in der Fahrzeug-DB als `out` markiert sind.
  - Diese Fahrzeuge können gegen `Config.Impound.fee` wieder gespawnt werden.
  - Das ist bewusst DB-Status-basiert, weil FiveM nach einem Restart nicht sicher wissen kann, ob ein Fahrzeug-Entity noch draußen existiert.

Neue Config:

```lua
Config.Impound = {
    enabled = true,
    fee = 500,
    label = 'Impound',
    allowFromEveryPublicGarage = true
}
```

### Impound-Check

Der Impound zeigt Fahrzeuge mit DB-Status `out` nicht mehr sofort an. Der Server scannt alle `Config.Impound.checkIntervalMinutes` Minuten die aktuell existierenden Fahrzeuge und blendet ausgeparkte Fahrzeuge aus, solange ihr Kennzeichen draußen gefunden wird. Standard: 5 Minuten.
