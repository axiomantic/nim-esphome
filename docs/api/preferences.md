# Module: `nim_esphome/preferences`

Flash-backed Non-Volatile Storage (NVS) persistence for primitive types, custom objects, and strings across microcontroller power cycles and reboots.

---

## Procedures

### `fnv1a`
```nim
proc fnv1a*(s: string): uint32
```
Computes a 32-bit Fowler–Noll–Vo (FNV-1a) hash for the string `s`. Converts string keys into deterministic 32-bit NVS storage keys.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `s` | `string` | Input string to hash. |

**Returns:**
- `uint32`: 32-bit unsigned FNV-1a hash integer.

---

### `savePreference` (Typed)
```nim
proc savePreference*[T](key: uint32, val: T): bool
proc savePreference*[T](key: string, val: T): bool
```
Persists a binary copy of value `val` of type `T` into flash storage under `key`. The string overload hashes `key` via FNV-1a.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `key` | `uint32` or `string` | Storage identifier (32-bit integer or string key). |
| `val` | `T` | Fixed-size value of type `T` to persist. |

**Returns:**
- `bool`: `true` if write succeeded, `false` otherwise.

---

### `loadPreference` (Typed)
```nim
proc loadPreference*[T](key: uint32, defaultVal: T): T
proc loadPreference*[T](key: string, defaultVal: T): T
```
Loads a value of type `T` from flash storage under `key`. Returns `defaultVal` if the key does not exist or a size mismatch occurs.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `key` | `uint32` or `string` | Storage identifier (32-bit integer or string key). |
| `defaultVal` | `T` | Fallback value returned if key is missing. |

**Returns:**
- `T`: Loaded value of type `T` or `defaultVal`.

---

### `savePreference` (String)
```nim
proc savePreference*(key: uint32, val: string): bool
proc savePreference*(key: string, val: string): bool
```
Persists a null-terminated string `val` into flash storage under `key`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `key` | `uint32` or `string` | Storage identifier (32-bit integer or string key). |
| `val` | `string` | String to persist. |

**Returns:**
- `bool`: `true` if write succeeded, `false` otherwise.

---

### `loadPreference` (String)
```nim
proc loadPreference*(key: uint32, defaultVal: string, maxLen: int = 128): string
proc loadPreference*(key: string, defaultVal: string, maxLen: int = 128): string
```
Loads a string from flash storage under `key` with maximum buffer size `maxLen`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `key` | `uint32` or `string` | Storage identifier (32-bit integer or string key). |
| `defaultVal` | `string` | Fallback string returned if key is missing. |
| `maxLen` | `int` | Maximum allowable string buffer length (default: 128). |

**Returns:**
- `string`: Loaded string or `defaultVal`.
