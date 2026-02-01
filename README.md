# 📦 Storage Organizer

**Version:** 1.0.0  

A Guild Wars storage organizer that automatically sorts your Xunlai storage.

**Happy Organizing!** 🎉

## ✨ Features

- **Automatic Categorization**: Sorts items into predefined categories
- **Priority Sorting**: High-value items (cupcakes, consets) sorted first within their category
- **Rarity Sorting**: Weapons and armor sorted by rarity (Green > Gold > Purple > Blue > White)
- **Multi-Client Support**: Works with multiple Guild Wars instances
- **Safety Features**: Pre-sort validation, safe item movement with retries
- **Progress Tracking**: Visual progress bar during sorting
- **Error Handling**: Graceful error recovery

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
3. **Click "Start Sort"**: Begin the sorting process
4. **Wait for completion**: Monitor progress in the log window

### ⚠️ Important Notes

- **Must be in an outpost** to sort storage
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

### "Failed to move item"
- Usually resolves itself with retries
- If persistent, try restarting Guild Wars
- Check that storage is not completely full

### Sorting seems stuck
- Check the log for error messages
- Use "Cancel" and try again
- Verify network connection to Guild Wars servers

## ⛔ Limitations

- Does not sort inventory bags (future feature)
- Does not sell or destroy items
- Does not stack items (future feature)
- Requires manual placement in outpost - no automatic travel

## 💡 Future Features

Planned enhancements for future versions:

- Customizable category order (Configuration GUI)
- Custom item priority rules
- Item restacking (consolidate stacks)
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