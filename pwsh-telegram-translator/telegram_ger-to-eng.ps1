$TG_BOT_API_KEY = '###PUT TELEGRAM BOT API KEY IN HERE###' #Telegram Bot API-KEY
$AZ_TRANSLATION_API_KEY = '###PUT AZURE TRANSLATION API KEY IN HERE###' # Azure Translation API KEY
$AZ_SPEECH2TEXT_API_KEY = '### PUT AZURE TEXT-TO-SPEECH API KEY IN HERE ###' #Azure Text-to-Speech API KEY
$WINDOWS_TEMPFOLDER = $env:TEMP + '\TelegramTranslatorBot\'
$TELEGRAM_TEMPFILE = $WINDOWS_TEMPFOLDER + 'temp.oga'
$TEXT2SPEECH_TEMPFILE = $WINDOWS_TEMPFOLDER + 'english.mp3'

# Wir checken erstmal, ob der Tempordner bereits erstellt wurde. Falls nicht, erstellen wir diesen.

If (Test-Path $WINDOWS_TEMPFOLDER) {
    Write-Host 'Der Ordner besteht bereits, alles prima!'
} else {
    New-Item $WINDOWS_TEMPFOLDER -ItemType Directory
    Write-Host 'Der Ordner wurde erstellt.'
}



# Im ersten Schritt werden neue Nachrichten über die Telegram-API abgefragt. Gleichzeitig wird die Result_Id abgefragt und für die nächste Anfrage +1 gesetzt.
$TG_GETNEWMSG_URI = 'https://api.telegram.org/bot' + $TG_BOT_API_KEY + '/getUpdates'
$TG_GETNEWMSG_REQ = Invoke-Webrequest -uri $TG_GETNEWMSG_URI
$TG_GETNEWMSG_REQ_JSON = ConvertFrom-Json -InputObject $TG_GETNEWMSG_REQ

$TG_GETNEWMSG_REQ_JSON_MSGS = $TG_GETNEWMSG_REQ_JSON.result.message

foreach ($TG_GETNEWMSG_MSG in $TG_GETNEWMSG_REQ_JSON_MSGS) {
    # Hier werden nun für jede empfangene Nachricht jeweils die File-ID zur dazugehörigen Voice-ID zugeordnet und das Voicefile vom Telegramserver heruntergeladen und im Temp-Ordner gespeichert.
    $TG_GETNEWMSG_MSG_CHAT_ID = $TG_GETNEWMSG_MSG.chat.id
    $TG_GETNEWMSG_MSG_FILEID_URI = 'https://api.telegram.org/bot' + $TG_BOT_API_KEY + '/getFile?file_id=' + $TG_GETNEWMSG_MSG.voice.file_id
    $TG_GETNEWMSG_MSG_FILEID_REQ = Invoke-WebRequest -Uri $TG_GETNEWMSG_MSG_FILEID_URI
    $TG_GETNEWMSG_MSG_FILEID_REG_JSON = ConvertFrom-Json -InputObject $TG_GETNEWMSG_MSG_FILEID_REQ
    $TG_GETNEWMSG_MSG_FILE_URI = 'https://api.telegram.org/file/bot' + $TG_BOT_API_KEY + '/' + $TG_GETNEWMSG_MSG_FILEID_REG_JSON.result.file_path
    Invoke-WebRequest -uri $TG_GETNEWMSG_MSG_FILE_URI -OutFile $TELEGRAM_TEMPFILE

    # Nun wird die Audiofile in Azure hochgeladen und der gesprochene Text verschriftlicht.
    $AZ_SPEECH2TEXT_URI = 'https://eastus.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=de-DE'
    $AZ_SPEECH2TEXT_HEADERS = @{
                                        'Ocp-Apim-Subscription-Key' = $AZ_SPEECH2TEXT_API_KEY
                                        'Content-Type' = 'audio/oga'
    }
    $AZ_SPEECH2TEXT_REQ = Invoke-RestMethod -Method Post -Uri $AZ_SPEECH2TEXT_URI -Headers $AZ_SPEECH2TEXT_HEADERS -InFile $TELEGRAM_TEMPFILE
    $AZ_SPEECH2TEXT_RES = $AZ_SPEECH2TEXT_REQ.DisplayText
    $AZ_SPEECH2TEXT_RES_SUBST = $AZ_SPEECH2TEXT_RES.Replace('Ö','OE').Replace('Ä','AE').Replace('Ü','UE').Replace('ü','ue').Replace('ä','ae').Replace('ö','oe')
    Write-Host $AZ_SPEECH2TEXT_RES_SUBST

    # Nun übersetzen wir den Text, schicken ihn zu Azures Text-to-Speech Engine, laden die Audiofile herunter und senden uns in Telegram den Text und die dazugehörige Audiofile
    $AZ_TRANSLATION_URI = 'https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=en'
    $AZ_TRANSLATION_HEADERS = @{
        'Ocp-Apim-Subscription-Key' = $AZ_TRANSLATION_API_KEY
        'Ocp-Apim-Subscription-Region' = 'eastus'
        'Content-Type' = 'application/json'
    }
    $AZ_TRANSLATION_BODY = @{
        'Text' = $AZ_SPEECH2TEXT_RES_SUBST
    }
    $AZ_TRANSLATION_BODY_JSON = ConvertTo-Json -InputObject $AZ_TRANSLATION_BODY
    $AZ_TRANSLATION_BODY_JSON_FORAPI = '[' + $AZ_TRANSLATION_BODY_JSON + ']'
    $AZ_TRANSLATION_REQ = Invoke-WebRequest -Uri $AZ_TRANSLATION_URI -Headers $AZ_TRANSLATION_HEADERS -Method Post -Body $AZ_TRANSLATION_BODY_JSON_FORAPI
    $AZ_TRANSLATION_RES = ConvertFrom-Json -InputObject $AZ_TRANSLATION_REQ.Content
    $AZ_TRANSLATION_RES_TRANSLATED = $AZ_TRANSLATION_RES.translations.text
    
    #Nun haben wir den Text übersetzt! Jetzt erstellen wir noch das Audiofile über Azure und laden es herunter.

    $AZ_TEXT2SPEECH_URI = 'https://eastus.tts.speech.microsoft.com/cognitiveservices/v1'
    $AZ_TEXT2SPEECH_HEADERS = @{
                                        'Ocp-Apim-Subscription-Key' = $AZ_SPEECH2TEXT_API_KEY
                                        'Content-Type' = 'application/ssml+xml' 
                                        'X-Microsoft-OutputFormat' = 'audio-16khz-128kbitrate-mono-mp3' 
                                        'User-Agent' = 'curl'
    }
    $AZ_TEXT2SPEECH_DATA = '<speak version="1.0" xml:lang="en-US"><voice xml:lang="en-US" xml:gender="Male" name="en-US-EricNeural">'+ $AZ_TRANSLATION_RES_TRANSLATED +'</voice></speak>'
    Invoke-RestMethod -Uri $AZ_TEXT2SPEECH_URI -Headers $AZ_TEXT2SPEECH_HEADERS -Method Post -Body $AZ_TEXT2SPEECH_DATA -OutFile $TEXT2SPEECH_TEMPFILE

    #Jetzt senden wir den Text per Telegram zurück
    $TG_SENDMESSAGE_URI = 'https://api.telegram.org/bot5518301784:AAF4rys52XyzRDkpz2pZcNuiRkD3u0VhA-Q/SendMessage?chat_id='+ $TG_GETNEWMSG_MSG_CHAT_ID +'&text='+ $AZ_TRANSLATION_RES_TRANSLATED
    Invoke-Webrequest -SkipCertificateCheck -uri $TG_SENDMESSAGE_URI
    #Jetzt senden wir die Audiofile in Telegram zurück

    $TG_SENDAUDIO_URI = 'https://api.telegram.org/bot' + $TG_BOT_API_KEY + '/sendAudio?chat_id=' + $TG_GETNEWMSG_MSG_CHAT_ID
    $TG_SENDAUDIO_FILE = @{
        audio = Get-Item -Path $TEXT2SPEECH_TEMPFILE

    }
    Invoke-Webrequest -Uri $TG_SENDAUDIO_URI -Method Post -Form $TG_SENDAUDIO_FILE

}

# Nun sind alle Nachrichten über die Schleife abgearbeitet. Wir müssen jetzt die /getUpdates-Liste leeren. Hierfür ziehen wir uns die Update-ID, setzen diese +1 hoch und fragen nochmal ab. Da wir keine neuen Nachrichten erwarten sollte nun unser Telegram-Bot aufgeräumt sein
$TG_GETNEWMSG_UPDATEID = $TG_GETNEWMSG_REQ_JSON.result.update_id | measure -Maximum
$TG_GETNEWMSG_UPDATEID_NEXT = $TG_GETNEWMSG_UPDATEID.Maximum + 1

$TG_CLEAR_URI = 'https://api.telegram.org/bot' + $TG_BOT_API_KEY + '/getUpdates?offset=' + $TG_GETNEWMSG_UPDATEID_NEXT
Invoke-Webrequest -SkipCertificateCheck -uri $TG_CLEAR_URI
