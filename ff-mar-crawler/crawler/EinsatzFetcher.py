import requests
from bs4 import BeautifulSoup
from .EinzelEinsatz import EinzelEinsatz
import csv
from datetime import datetime

class EinsatzFetcher():
    def fetch(self):
        url = "https://ffw-marktheidenfeld.de/einsatzabteilung/einsatzuebersicht/"
        abfrage = requests.get(url)
        doc = BeautifulSoup(abfrage.text, "html.parser")

        for report in doc.select(".report"):
            e_lfdnr = report.select_one(".einsatz-column-seqNum").text
            e_datetime = report.select_one(".einsatz-column-datetime").text
            e_duration = report.select_one(".einsatz-column-duration").text
            e_title = report.select_one(".einsatz-column-title").text
            e_incidenttype = report.select_one(".einsatz-column-incidentType").text
            e_location = report.select_one(".einsatz-column-location").text
            e_ispicture = report.select_one(".fa-camera").attrs["title"]
            yield EinzelEinsatz(e_lfdnr, e_datetime, e_duration, e_title, e_incidenttype, e_location, e_ispicture)

        with open("csv-files/requests.csv", "w", newline="") as abfragencsv:
            csventry = csv.writer(abfragencsv, delimiter=";")
            csventry.writerow ([datetime.now().strftime("%d.%m.%y")])
