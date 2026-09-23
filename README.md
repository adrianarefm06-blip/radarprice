# RadarPrice · Capa de datos (Agente 2)

## Dependencias (`pubspec.yaml`)
```yaml
environment:
  sdk: ^3.5.0
dependencies:
  flutter_riverpod: ^3.0.0   # compatible también con ^2.6.1
  collection: ^1.18.0
  google_fonts: ^6.2.1       # Agente 1: Archivo / Archivo Narrow
```
Sin codegen (no freezed/json_serializable): copiar y compilar.
Los tests asumen `name: radarprice` en pubspec.

## Estructura
```
lib/
├── core/
│   ├── constants/sizes.dart          kSupportedSizes
│   └── errors/app_exceptions.dart    sealed AppException
├── domain/
│   ├── models/                       Product, StoreOffer, PricePoint, PriceAlert (+ models.dart)
│   └── repositories/                 ProductRepository, AlertRepository (interfaces)
├── data/mock/
│   ├── mock_catalog.dart             3 modelos × 5 tallas × 3-4 tiendas (EUR)
│   ├── mock_product_repository.dart  latencia 350 ms, histórico determinista
│   └── mock_alert_repository.dart    persistencia en memoria + 3 alertas semilla
└── application/providers/            providers.dart (barrel)
test/data_layer_test.dart
```

## Contrato para la UI (Agente 1)
| Provider | Tipo | Uso |
|---|---|---|
| `selectedSizeFilterProvider` | `String?` | `.notifier.toggle('42.5')`, `.clear()` |
| `hotDealsProvider` | `AsyncValue<List<Product>>` | Feed. Refresh: `ref.refresh(hotDealsProvider.future)` |
| `productSearchProvider((query:, size:))` | `AsyncValue<List<Product>>` | Debounce 250 ms incluido |
| `productBySkuProvider(sku)` | `AsyncValue<Product>` | Detalle |
| `priceHistoryProvider((sku:, days:))` | `AsyncValue<List<PricePoint>>` | Gráfica |
| `alertsProvider` | `AsyncValue<List<PriceAlert>>` | `.notifier.toggle(id)`, `.notifier.create(PriceAlert.draft(...))` |

Helpers en `Product`: `availableSizes`, `offersForSize`, `bestOfferForSize`,
`lowestPriceForSize`, `savingsPercent(ForSize)` (negativo = precio reventa > retail).
`PriceAlert.isTriggeredBy(product)` para el badge "¡Objetivo alcanzado!".

## Notas
- `imageUrl`/`storeLogoUrl` apuntan a `cdn.radarprice.app` (placeholders): usar `errorBuilder`.
- Riverpod 3 reintenta providers con error por defecto. Para no reintentar errores de dominio:
  ```dart
  ProviderScope(
    retry: (count, error) => error is AppException || count >= 3 ? null : Duration(milliseconds: 200 << count),
    child: const App(),
  )
  ```
- Migración a backend: implementar `ProductRepository`/`AlertRepository` y cambiar
  `repository_providers.dart`. Nada más.

## Capa de presentación (Agente 1)
```
lib/
├── main.dart                     ProviderScope(retry) + MaterialApp dark
└── presentation/
    ├── theme/                    AppColors, AppTheme, AppTypography, AppRadius
    ├── router/app_router.dart    rutas '/' y '/product' (args: Product o SKU)
    ├── utils/formatters.dart     formatPrice / formatPercent (es-ES, sin intl)
    ├── screens/                  AppShell, Home, Search, Alerts, ProductDetail
    └── widgets/                  ProductCard, SizeSelector, PriceLine, DiscountBadge,
                                  SneakerImage, StoreLogo, Shimmer, StateViews
```
Reglas de diseño: menta = ahorro, naranja = sobre retail; el precio (Archivo Narrow,
dígitos tabulares) es el protagonista; chip de talla activo en blanco invertido.
