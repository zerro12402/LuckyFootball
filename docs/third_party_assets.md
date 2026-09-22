# Third-party asset register

This register records the provenance and release status of external assets in
`res://assets/`. An asset whose license is marked **unverified** is limited to
local prototyping and must not be included in a public or commercial build.

## Fonts

| Runtime asset | Author or source | License | Modification | Release status |
| --- | --- | --- | --- | --- |
| `assets/fonts/daydream.ttf` | Doublegum (`@doublegum_`) | Personal use only. Commercial license: <https://gum.co/MeHRC> | Renamed only | Local prototype only until a commercial license is recorded |
| `assets/fonts/pixeled.ttf` | Unknown | Unverified | Renamed only | Local prototype only |

The original Daydream license notice is stored beside the font as
`assets/fonts/daydream_personal_license.txt`.

## Art

The PNG files under `assets/art/` arrived as one imported asset set. Their
original download URL, author, license, and editable source files were not
provided. They have only been reorganized and renamed; their image content has
not been modified.

Release status: **local prototype only** until provenance and commercial-use
permission are recorded here. Add the editable originals under
`assets/source/art/` when they become available.

## Audio

The MP3 and WAV files under `assets/audio/` arrived without source or license
metadata. Their file content and format have not been modified. Looping music
was renamed with the `_loop` suffix to match its Godot import setting.

Release status: **local prototype only** until provenance and commercial-use
permission are recorded here. Add lossless originals under
`assets/source/audio/` when they become available.

## Generated assets

No asset is currently identified as generated content. If generated material
is added, record its generator, prompt or prompt version, license terms, and
manual modifications in this file.
