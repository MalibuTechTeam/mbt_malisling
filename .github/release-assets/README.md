# Release assets

Immagini referenziate dal README principale. Metti qui i file **con questi nomi esatti**:

| File | Cosa deve mostrare | Da dove |
|---|---|---|
| `hero.png` | Il personaggio con l'arma in spalla, di tre quarti. È la prima cosa che si vede sulla pagina GitHub. | Frame dalla **clip 01** o **clip 02** del video |
| `inspect.png` | L'overlay di ispezione aperto, con serial e chain of custody **leggibili**. | Frame dalla **clip 08** |
| `dashboard.png` | La dashboard admin aperta su una categoria, non su una pagina vuota. | Frame dalla **clip 12** |

Poi apri `README.md` e **decommenta** i due blocchi marcati
`<!-- SLOT IMMAGINE -->` — sono già scritti, basta togliere `<!--` e `-->`.

- Nel blocco **hero**: sostituisci l'URL cloudfront con `.github/release-assets/hero.png`.
- Nel blocco **preview**: dopo aver tolto i marcatori, aggiungi una riga `---` in fondo
  alla sezione (non è dentro il commento di proposito: `--->` rompe il parser HTML).

## Note

- **PNG**, larghezza 1600-2000px. GitHub scala da solo.
- **Niente HUD del server, niente chat, niente nickname** nel frame.
- Il testo dell'overlay deve essere leggibile **alla larghezza a cui GitHub lo mostra**
  (~900px su desktop). Se devi strizzare gli occhi nel PNG originale, sulla pagina
  sparisce.
- Non usare URL esterni: il CDN CFX/Tebex attuale non è nostro e può sparire.
