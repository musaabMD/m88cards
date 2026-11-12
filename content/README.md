# content

Every deck the app ships with. One `.json` file per subject; drop a new file here, rebuild, and it
appears on the Home screen. Format:

```json
{ "id": "anatomy", "name": "Anatomy", "color": "#2563EB",
  "topics": [ { "id": "anatomy/upper-limb", "name": "Upper limb",
    "cards": [ { "id": "ul-1", "q": "Nerve of the thenar muscles?", "a": "Median (recurrent branch)", "note": "optional" } ] } ] }
```

`id`s must be unique across all files (progress is keyed by card id). `color` and `note` are optional.
