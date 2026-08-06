# Release assets

Immagini usate dal README principale, estratte dal master del video showcase
(`Sequenza 01_3.mxf`, ProRes 4K) con ffmpeg.

| File | Timecode | Cosa mostra |
|---|---|---|
| `hero.jpg` | 0:20 | Fucile in spalla sul ponte della portaerei, card EQUIPPED |
| `inspect.jpg` | 1:14 | Card di ispezione: serial, condizione, catena di possesso |
| `dashboard.jpg` | 1:20 | Dashboard admin, pagina Handling + riepilogo feature |

## Come rigenerarle

```bash
ffmpeg -y -ss 20   -i "master.mxf" -frames:v 1 -vf scale=1920:-2 -q:v 3 hero.jpg
ffmpeg -y -ss 74.5 -i "master.mxf" -frames:v 1 -vf scale=1920:-2 -q:v 3 inspect.jpg
ffmpeg -y -ss 80   -i "master.mxf" -frames:v 1 -vf scale=1920:-2 -q:v 3 dashboard.jpg
```

**JPEG e non PNG**: gli stessi tre fotogrammi in PNG pesavano 25 MB contro 700 KB, per
una differenza che a schermo non si vede. Un PNG ha senso per la UI a tinte piatte,
non per un frame di gioco.

**1920px di larghezza**: GitHub mostra il README a circa 900px, quindi 1920 copre gli
schermi a densità doppia senza sprecare banda.

## ⚠️ `inspect.jpg` contiene un refuso

Nella catena di possesso si legge **"Jhon Black"** invece di "John". Viene dal
personaggio di test usato durante le riprese, ed è l'immagine più guardata delle tre
perché documenta la feature che distingue lo script.

Per rifarla serve una cattura in gioco con un nome pulito, poi:

```bash
ffmpeg -y -i cattura.png -vf scale=1920:-2 -q:v 3 inspect.jpg
```
