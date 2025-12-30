# EasyToYou ionCube Decoder Script

Automated bash script to decode ionCube-encoded PHP files using the EasyToYou.eu web service.

## Features

- 🔍 **Smart Detection** - Automatically identifies encoded files by checking for ionCube loader signatures
- 🔄 **Batch Processing** - Recursively processes entire directory trees
- 💾 **Automatic Backups** - Creates `.php_bck` or `.pdt_bck` backups before decoding
- 🎯 **Selective Processing** - Skips already-decoded files to avoid unnecessary uploads
- 📦 **Multiple Formats** - Supports both `.php` and `.pdt` file extensions
- 🔒 **Session Management** - Maintains login cookies for efficient batch operations
- 🛡️ **Error Handling** - Continues processing even if individual files fail
- 🤖 **Bot Detection Bypass** - Uses realistic browser headers to avoid blocking

## Requirements

- `bash` 4.0+
- `curl`
- `grep`
- Valid EasyToYou.eu account credentials

## Installation

```bash
# Download the script
wget https://example.com/download.sh

# Make it executable
chmod +x download.sh
```

## Usage

### Basic Syntax

```bash
./download.sh -u USERNAME -p PASSWORD -s SOURCE_DIR [-d DECODER] [-w]
```

### Options

| Option | Description | Required | Default |
|--------|-------------|----------|---------|
| `-u` | EasyToYou.eu username | ✅ Yes | - |
| `-p` | EasyToYou.eu password | ✅ Yes | - |
| `-s` | Source directory to process | ✅ Yes | - |
| `-d` | Decoder version to use | ❌ No | `ic11php72` |
| `-w` | Force overwrite (ignores backups) | ❌ No | `false` |

### Available Decoders

| Decoder ID | PHP Version | ionCube Version |
|------------|-------------|-----------------|
| `ic11php70` | PHP 7.0 | ionCube 11 |
| `ic11php71` | PHP 7.1 | ionCube 11 |
| `ic11php72` | PHP 7.2 | ionCube 11 |
| `ic11php74` | PHP 7.4 | ionCube 11 |
| `ic11php56` | PHP 5.6 | ionCube 11 |
| `ic11php55` | PHP 5.5 | ionCube 11 |
| `ic11php54` | PHP 5.4 | ionCube 11 |
| `ic11php53` | PHP 5.3 | ionCube 11 |
| `ic11php50` | PHP 5.0 | ionCube 11 |

## Examples

### Decode a Single Directory

```bash
./download.sh -u myuser -p 'mypassword' -s ./my-project
```

### Decode with Specific PHP Version

```bash
./download.sh -u myuser -p 'mypassword' -s ./my-project -d ic11php74
```

### Force Reprocess Already-Decoded Files

```bash
./download.sh -u myuser -p 'mypassword' -s ./my-project -w
```

### Process Multiple Directories

```bash
./download.sh -u myuser -p 'mypassword' -s ./project1
./download.sh -u myuser -p 'mypassword' -s ./project2
```

### Handle Paths with Spaces

```bash
./download.sh -u myuser -p 'mypassword' -s './My Project Folder'
# or
./download.sh -u myuser -p 'mypassword' -s ../My\ Project\ Folder
```

## How It Works

1. **Login** - Authenticates with EasyToYou.eu and stores session cookie
2. **Scan** - Recursively finds all `.php` and `.pdt` files in the source directory
3. **Detect** - Checks each file for ionCube loader signatures:
   - `extension_loaded('ionCube Loader')`
   - `extension_loaded("ionCube Loader")`
4. **Backup** - Creates `filename.php_bck` backup of encoded file
5. **Upload** - Sends file to EasyToYou decoder service
6. **Download** - Retrieves decoded file
7. **Replace** - Overwrites original with decoded version
8. **Repeat** - Continues with next file

## File Processing Logic

### What Gets Processed

✅ Files containing ionCube loader checks  
✅ Both `.php` and `.pdt` extensions  
✅ Files without existing backups (unless `-w` used)

### What Gets Skipped

❌ Already decoded files (no ionCube signature)  
❌ Files with existing `_bck` backups (unless `-w` used)  
❌ Non-PHP files

## Output Examples

### Successful Processing

```
[*] Logging in...
[+] Login successful
[*] Processing encoded file: ./project/encode.php
[*] Using upload field: 192912[]
[*] Uploading encode.php...
[+] Successfully decoded: ./project/encode.php
[*] Done.
```

### Skipping Decoded Files

```
[*] Skipping ./project/already-decoded.php (not encoded)
```

### Failed Decode

```
[*] Processing encoded file: ./project/problematic.php
[-] File cannot be decoded: ./project/problematic.php
```

## File Structure After Processing

```
project/
├── encoded.php          # ← Decoded version (replaced)
├── encoded.php_bck      # ← Original encoded backup
├── config.pdt           # ← Decoded version
├── config.pdt_bck       # ← Original encoded backup
└── plain.php            # ← Skipped (not encoded)
```

## Troubleshooting

### "Login failed"

- Verify your username and password are correct
- Check if your account is active on EasyToYou.eu
- Ensure you have sufficient credits/access

### "Bot detection triggered"

- The script automatically retries with adjusted headers
- If persistent, wait a few minutes and try again
- Consider adding longer delays between batches

### "Failed to get upload field name"

- EasyToYou.eu may have changed their form structure
- Update the script or contact support
- Try with fewer concurrent requests

### "File cannot be decoded"

- File may use unsupported ionCube version
- Try different decoder version with `-d` option
- File may be corrupted or have additional protection

### Files Being Skipped

- Check if `_bck` files exist (use `-w` to force reprocess)
- Verify files actually contain ionCube encoding
- Use `grep "ionCube" file.php` to check manually

## Security Notes

⚠️ **Password Handling**
- Use single quotes around passwords: `-p 'my!pass'`
- Avoid storing credentials in shell history
- Consider using environment variables:
  ```bash
  read -s -p "Password: " PASS
  ./download.sh -u myuser -p "$PASS" -s ./project
  ```

⚠️ **Backup Files**
- Always keep `_bck` files until you verify decoded files work
- Consider making additional backups before running the script
- The script creates backups but doesn't handle rollbacks

⚠️ **Rate Limiting**
- Script includes 1-second delay between files
- Processing large batches may take significant time
- Avoid running multiple instances simultaneously

## Limitations

- Requires active internet connection
- Depends on EasyToYou.eu service availability
- Some ionCube versions may not be supported
- Files with additional protection layers may fail
- Rate limits may apply based on your account tier

## Best Practices

1. **Test First** - Run on a single file/small directory before batch processing
2. **Keep Backups** - Don't delete `_bck` files until you verify everything works
3. **Check Results** - Manually verify a few decoded files before deploying
4. **Use Correct Decoder** - Match the decoder to your PHP version
5. **Monitor Progress** - Watch for error messages during batch processing

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Login failed or missing required arguments |

## Version History

- **v1.0** - Initial release with smart detection and batch processing
- Automatic backup creation
- Bot detection bypass
- Multi-format support (.php and .pdt)

## License

This script is provided as-is for use with EasyToYou.eu service. Use at your own risk.

## Support

For issues with:
- **The script**: Check the troubleshooting section above
- **EasyToYou.eu service**: Contact https://easytoyou.eu/user/contact.php
- **ionCube decoding**: Verify file encoding version and decoder compatibility

## Credits

Developed for automated ionCube decoding workflows using the EasyToYou.eu web service.
