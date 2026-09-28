# soft/ — локальные сборки для VibeBSD

Здесь лежат `.pkg`, которых нет в официальном репозитории FreeBSD: собственные
сборки AI-инструментов. Шаг пайплайна `18-install-soft.sh` ставит **все**
`*.pkg` из этой папки в jail (`pkg -r <jail> add -M`), регистрирует их в БД
jail и проверяет, что бинарь на месте.

| пакет | версия | размер | лицензия | что это |
|-------|--------|--------|----------|---------|
| `opencode-*.pkg` | 0.0.0.20260805 | 49 МБ → 212 МБ | MIT | AI-агент в терминале, динамическая сборка (koffi) |
| `dmed-*.pkg` | 0.8.3 | 5 МБ → 17 МБ | BSD-3-Clause | dmEd — терминальный редактор кода, AI-агенты как первоклассные участники |
| `dmcode-*.pkg` | 0.1.3 | 7.7 МБ → 36 МБ | MIT | Терминальный агент на google/adk-go + Bubble Tea, статический Go |

## Требования к пакету

- ABI в манифесте: `FreeBSD:15:amd64` (иначе `18-install-soft.sh` падает).
- Один бинарь в `/usr/local/bin/<имя>` — этого достаточно.
- Собирается: `tar -xOf <file>.pkg +MANIFEST | head`.

## Пересборка

Все три собираются из исходников на FreeBSD-хосте.

```sh
# dmed (статический Go, без CGO)
git clone --depth 1 https://github.com/dedomorozoff/dmed
cd dmed && gmake build-freebsd-amd64

# dmcode (статический Go, без CGO; go.mod требует 1.26)
git clone --depth 1 https://github.com/dedomorozoff/dmcode
cd dmcode && GOTOOLCHAIN=auto gmake build-freebsd-amd64

# dmsh (CGO + llama.cpp из сабмодуля, тяжёлая сборка)
git clone --recursive --depth 1 https://github.com/dedomorozoff/dmsh
cd dmsh
cmake -S third_party/llama.cpp -B third_party/llama.cpp/build \
  -DBUILD_SHARED_LIBS=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_BUILD_SERVER=OFF -DGGML_NATIVE=OFF -DGGML_CUDA=OFF
cmake --build third_party/llama.cpp/build --parallel 6
CGO_ENABLED=1 \
  CGO_CFLAGS="-I$PWD/third_party/llama.cpp/build/include" \
  CGO_LDFLAGS="-L$PWD/third_party/llama.cpp/build/lib" \
  go build -tags llama -ldflags "-s -w" -o bin/dmsh ./cmd/dmsh
```

`gmake`, а не `make`: на FreeBSD `make` — это bmake, а Makefile'ы всех трёх
проектов написаны под GNU make.

## Упаковка в .pkg

```sh
pkg create -M manifest.json -r stage/ -o soft/ -f tzst
```

Либо готовым помощником: `sh soft/mkfreebsd-pkg.sh <бинарь> <имя> <версия> <лицензия> <url> <описание> [коммит]`.

Модель для `dmsh` (GGUF) в образ не входит: `dmsh` качает её сам с HuggingFace
при первом запуске, либо берёт локальный путь из `~/.config/dmsh/config.json`.
