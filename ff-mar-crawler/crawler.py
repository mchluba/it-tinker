import crawler
import csv
from datetime import datetime
import requests
import shutil

fetcher = crawler.EinsatzFetcher()
alle_einsaetze = []
alte_einsaetze = []
neue_einsaetze = []

with open("csv-files/alle_einsaetze.csv", "w", newline="") as csvfile:
    for element in fetcher.fetch():
        csventry = csv.writer(csvfile, delimiter=";", quotechar='"', quoting=csv.QUOTE_ALL)
        csventry.writerow([element.lfdnr] + [element.title] + [element.datetime] + [element.incidenttype] + [element.location] + [element.duration] + [element.ispicture])
        alle_einsaetze.append(element.lfdnr)

with open("csv-files/alte_einsaetze.csv", "r", newline="") as csvfile:
    csvread = csv.reader(csvfile, delimiter=";", quotechar='"')
    for row in csvread:
        alte_einsaetze.append(row[0])

for i in alle_einsaetze:
    neue_einsaetze.append(i)

for i in alte_einsaetze:
    neue_einsaetze.remove(i)

telegram_url = "https://api.telegram.org/bot1222928937:AAGWFeILCVnJAjNGNDBB068uFx4qgXWoMTM/sendMessage?chat_id=-788422580&text="

with open("csv-files/alle_einsaetze.csv", "r", newline="") as csvfile:
    csvread = csv.reader(csvfile, delimiter=";", quotechar='"')
    for row in csvread:
        if row[0] in neue_einsaetze:
            text = "NEUER EINSATZBERICHT\nDatum und Uhrzeit: " + row[2] + "\nEinsatzort: " + row[4] + "\nEinsatzart: " + row[3] + "\n" + row[1]
            req = telegram_url + text
            requests.get(req)

shutil.copyfile ("csv-files/alle_einsaetze.csv", "csv-files/alte_einsaetze.csv")





        
        