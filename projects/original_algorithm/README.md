# original_algorithm

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# Notes:
```dart
// Deep copy: creates new List AND new object instances
List<Species> deepCopy = original
    .map((spe) => Species.makeCopy(spe)) // or your copy method
    .toList();
```

The main difference between `List.of` and `List.from` is **how and when types are checked** (compile-time vs. runtime).

---

### 1. `List.of` — Compile-time Type-Safe *(Recommended)*

* **Signature:** `List<E>.of(Iterable<E> elements, {bool growable = true})`
* **How it works:** The input iterable **must statically match** the element type `E` at compile time.
* **Performance:** **Faster**, because Dart knows all types are valid up front and doesn't need to inspect every item at runtime.
* **When to use:** Whenever you are copying a list whose type is already known.

```dart
List<Species> original = [species1, species2];

// ✅ Fast, compile-time verified
List<Species> copy = List.of(original); 
```

---

### 2. `List.from` — Runtime Type-Casting *(Downcasting)*

* **Signature:** `List<E>.from(Iterable elements, {bool growable = true})`
* **How it works:** Accepts `Iterable<dynamic>` and **downcasts every single element at runtime** to type `E`.
* **Performance:** **Slower**, because it performs runtime type checks on every element during iteration.
* **Failure:** If an element is not of type `E`, it throws a runtime `TypeError`.
* **When to use:** When converting loosely-typed collections (like deserialized JSON `List<dynamic>`) to a strongly-typed list.

```dart
// Example: JSON parsing gives List<dynamic>
dynamic rawData = [1, 2, 3]; 

// ✅ List.from casts each element at runtime to int
List<int> numbers = List<int>.from(rawData); 

// ❌ List.of(rawData) would fail to compile if rawData is dynamic/Object
```

---

### Summary Table

| Feature | `List.of(iterable)` | `List.from(iterable)` |
| :--- | :--- | :--- |
| **Type Check** | Compile-time | Runtime (per element) |
| **Input Type** | `Iterable<E>` | `Iterable<dynamic>` |
| **Speed** | Faster | Slower (runtime casting overhead) |
| **Best for** | Normal list cloning / copying | Downcasting loosely typed / JSON data |

> **Rule of thumb:** Always use **`List.of()`** (or `[...items]`) unless you specifically need runtime downcasting from `dynamic`.

# ====== Reverse iterator ======
### What the C++ code is doing
In C++, `it` is a **reverse iterator** (`std::vector<Species*>::reverse_iterator`).
* `std::prev(it.base())` simply converts the reverse iterator `it` back to the **same element's forward iterator**.
* `it == sorted_species.rend()` means the reverse search reached the end (i.e. stepped past the first element), so it defaults to `sorted_species.begin()` (index `0`).

---

### Dart Replacements (Index-based)

#### 1. If you are using a backward `for` loop index `i`:
If you looped backwards `for (int i = sortedSpecies.length - 1; i >= 0; i--)`:
```dart
// Index version:
int curSpeciesIndex = (i < 0) ? 0 : i;
Species curSpecies = sortedSpecies[curSpeciesIndex];
```
Or directly:
```dart
Species curSpecies = (i < 0) ? sortedSpecies.first : sortedSpecies[i];
```

---

#### 2. If `it` came from a reverse search (`std::find_if` on `rbegin`...`rend`):
In Dart, you can find the index directly using `lastIndexWhere`:

```dart
int index = sortedSpecies.lastIndexWhere((s) => /* your condition */);

// If not found (-1), fallback to the first element (index 0)
Species curSpecies = (index == -1) ? sortedSpecies.first : sortedSpecies[index];
```

---

#### Summary:
In Dart with zero-based indexing, you don't need reverse-to-forward iterator math at all:
$$\text{C++: } \texttt{std::prev(it.base())} \iff \text{Dart: } \texttt{sortedSpecies[i]}$$
$$\text{C++: } \texttt{it == rend()} \iff \text{Dart: } \texttt{i < 0 \text{ (or } index == -1\text{)}}$$

