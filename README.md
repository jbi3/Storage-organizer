# 📦 Storage Organizer

**Version:** 1.0.0  

A Guild Wars storage organizer that automatically sorts your Xunlai storage and your character inventory.

**Happy Organizing!** 🎉

## ✨ Features

- **Automatic Categorization**: Sorts items into predefined categories
- **Zones**: Sort the Xunlai storage, the character inventory (backpack, belt pouch, bags 1-2), or both; each zone is sorted on its own, no item moves between them
- **Priority Sorting**: High-value items (cupcakes, consets) sorted first within their category
- **Rarity Sorting**: Weapons and armor sorted by rarity (Green > Gold > Purple > Blue > White)
- **Multi-Client Support**: Works with multiple Guild Wars instances
- **Safety Features**: Pre-sort validation, safe item movement with retries
- **Progress Tracking**: Visual progress bar during sorting
- **Error Handling**: Graceful error recovery
- **Auto-Restack**: Before sorting, merges incomplete stacks of identical items (250 items max per stack), in each checked zone separately
- **Free Slots Placement**: Choose whether the free slots end up at the end (items from the first slot) or at the start (items up to the last slot); applies to every checked zone

## 🪄 Sorting Order

Items are sorted into the following categories (in order):

1. **Materials** - All crafting materials
2. **Consumables** - Priority order:
   - Birthday Cupcakes & Consets (Armor of Salvation, Essence of Celerity, Grail of Might)
   - Party consumables (pcons)
   - Other consumables
3. **Tomes** - Elite and regular skill tomes
4. **Trophies** - Rare and non-rare trophies
5. **Weapons** - Sorted by rarity, then type
6. **Armor** - Sorted by rarity, then type
7. **Other** - Everything else

### 🧱 Restack

Runs on every Start, before the sort, in each checked zone:
- Identical means same ModelID and ExtraID: dyes of different colours are never merged
- The first incomplete stack found is filled first, possibly with a part of another stack
- Inventory and storage are restacked separately: no item moves between them
- Material storage and equipment pack are excluded, as for the sort
- Each move is confirmed by the game; an unconfirmed move stops the run with a warning in the log

## ⚙️ Requirements

- **Guild Wars** (Game must be running)
- **[GwAu3](https://github.com/JAG-GW/GwAu3)** - Guild Wars AutoIt library
- **AutoIt3** - To run `.au3` scripts

## 🛠️ Installation
**⚠️ Disclaimer:** Use of automation tools may violate Guild Wars Terms of Service. Use at your own risk.

1. Clone or download the GwAu3 repository
2. Extract to: `GwAu3\Scripts`
3. Run `Storage-Organizer.au3`

## ▶️ Usage

### 🧭 Basic Steps

1. **Launch the script**: Run `Storage-Organizer.au3`
2. **Select character**: Choose your character from the dropdown
3. **Check the zones**: Xunlai storage (default), Inventory, or both
4. **Choose the placement**: Free slots at the end (default) or at the start
5. **Click "Start"**: Restack, then sort
6. **Wait for completion**: Monitor progress in the log window

### ⚠️ Important Notes

- **Must be in an outpost** to sort storage (the inventory alone can be sorted anywhere)
- **Character must be logged in** and in-game
- **Do not interfere** with the game while sorting is in progress

## 🧯 Troubleshooting

### "No clients found"
- Ensure Guild Wars is running
- Click "Refresh" to rescan
- Character must be logged in

### "Character must be in an outpost"
- Travel to any outpost
- Cannot sort storage in explorable areas or during missions
- Uncheck "Xunlai storage" to sort only the inventory there

### "Failed to move item"
- Usually resolves itself with retries
- If persistent, try restarting Guild Wars
- Check that storage is not completely full

### Sorting seems stuck
- Check the log for error messages
- Use "Cancel" and try again
- Verify network connection to Guild Wars servers

## ⛔ Limitations

- Does not sort the equipment pack
- Does not sell or destroy items
- Does not merge stacks between inventory and storage
- Requires manual placement in outpost - no automatic travel

## 💡 Future Features

Planned enhancements for future versions:

- Customizable category order (Configuration GUI)
- Custom item priority rules
- Sort profiles (save/load configurations)
- Inventory sorting support

## 🆘 Support

For issues, questions, or contributions:
- Examine log output for detailed error information

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author & Credits
Made by Arca, also known as jbi3.\
Credits to Touchwise for original GWA2 script PainInAss which inspired this one.