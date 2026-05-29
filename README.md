# Hand Project Android App

App Android sviluppata in Flutter per controllare la mano robotica del progetto Hand Project.

L'app comunica con il backend Laravel tramite API HTTP. Da qui i comandi vengono inviati alla mano fisica tramite MQTT.

## Funzioni principali

- Visualizzazione dello stato della mano.
- Controllo manuale delle dita.
- Comando per aprire tutta la mano.
- Comando per chiudere tutta la mano.
- Invio comandi al backend Laravel.
- Visualizzazione dell'ultimo payload inviato e della risposta ricevuta.

Le dita controllate sono:

- indice
- medio
- anulare
- mignolo

Il pollice non e' presente nella mano fisica, quindi non viene controllato dall'app.

## Flusso di funzionamento

```text
App Android -> API Laravel -> MQTT HiveMQ -> ESP32 mano -> servomotori
```

L'app non comunica direttamente con l'ESP32. Tutti i comandi passano prima dal sito/backend Laravel.

## Avvio del progetto

Aprire il progetto con Android Studio oppure usare il terminale:

```bash
flutter pub get
flutter run
```

## Indirizzo API

Nell'app e' presente un campo per impostare l'indirizzo del backend Laravel.

Se si usa l'emulatore Android:

```text
http://10.0.2.2:8000
```

Se si usa un telefono fisico, bisogna usare l'indirizzo IP del PC sulla stessa rete Wi-Fi:

```text
http://192.168.1.xxx:8000
```

In questo caso Laravel deve essere avviato con:

```bash
php artisan serve --host=0.0.0.0 --port=8000
```

## Comandi inviati

Esempio apertura mano:

```json
{
  "command": "open_all"
}
```

Esempio chiusura mano:

```json
{
  "command": "close_all"
}
```

Esempio movimento di un dito:

```json
{
  "command": "move_finger",
  "finger": "index",
  "targetPercentage": 80
}
```

## Verifica

Per verificare se i comandi arrivano al backend, controllare il log Laravel:

```bash
Get-Content .\storage\logs\laravel.log -Wait -Tail 50
```

Se compare `Comando mano ricevuto`, l'app sta comunicando correttamente con Laravel.

Se compare anche `Comando pubblicato su MQTT`, il comando e' stato inviato al broker MQTT.
