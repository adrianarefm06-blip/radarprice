# RadarPrice (app Flutter)

Comparador de precios de zapatillas por talla entre tiendas, con favoritos, historial y alertas.
Backend: [radarprice-api](https://github.com/adrianarefm06-blip/radarprice-api).

## Ejecutar
```bash
flutter pub get

# Backend local (emulador Android → 10.0.2.2)
flutter run

# Backend en Render (plan gratuito: el primer acceso tras dormir tarda ~1 min)
flutter run --dart-define=API_BASE_URL=https://radarprice-api.onrender.com --dart-define=API_TIMEOUT_SECONDS=60

# Release (HTTPS obligatorio: con http:// la app no arranca)
flutter build apk --release --dart-define=API_BASE_URL=https://radarprice-api.onrender.com
```

| `--dart-define` | Por defecto | Uso |
|---|---|---|
| `API_BASE_URL` | `http://10.0.2.2:8000` | URL del backend; en release debe ser `https://` |
| `API_TIMEOUT_SECONDS` | `30` | Espera máxima por petición (arranque en frío de Render) |

HTTP en claro solo está permitido en los manifiestos de debug/profile de Android.

## Estructura
```
lib/
├── core/            constantes y AppException (errores de dominio con mensaje para el usuario)
├── domain/          modelos (Product, StoreOffer, PriceAlert…), contratos de repositorio y
│                    servicios puros (comparador de chollos, búsqueda y orden)
├── infrastructure/  ApiClient + repositorios HTTP, favoritos (shared_preferences), X-Device-Id
├── data/mock/       repositorios en memoria para tests
├── application/     providers de Riverpod (catálogo, filtros, favoritos, alertas)
└── presentation/    pantallas y widgets
```

- El catálogo se carga una vez (`allDealsProvider`, paginado) y talla, segmento, búsqueda,
  orden y favoritos se aplican en memoria.
- Las ofertas de demostración (`source: "simulated"` en la API) se marcan siempre como "Est.".
- Alertas en el servidor, aisladas por un id aleatorio del dispositivo.

## Calidad
```bash
flutter analyze --fatal-infos
flutter test
```
El CI (GitHub Actions) ejecuta ambos en cada PR.
