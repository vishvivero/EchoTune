# EchoTune License Keys

## Quick Reference

You can use any of the following methods to generate a license key for EchoTune:

### Option 1: Demo License (Recommended for Testing)

**Format**: Any key starting with `DEMO-`

**Example**: 
- `DEMO-TEST-LICENSE-KEY`
- `DEMO-12345-ABCDE-FGHIJ`

**Activation**: 
- Tier: Pro (lifetime)
- Expiry: Never expires
- Features: Unlimited transcriptions, all models, 2 user licenses

### Option 2: Individual License

**Format**: `XXXXX-XXXXX-XXXXX-XXXXX` where X is A-Z or 0-9

**Example**:
- `ABCDE-FGHIJ-KLMNO-PQRST`
- `12345-67890-ABCDE-FGHIJ`

**Activation**:
- Tier: Individual
- Expiry: 1 year from activation
- Features: Unlimited transcriptions, all models, 1 user license

## Generating License Keys

### Using the Shell Script

Run the provided script:
```bash
./generate_license_key.sh
```

Choose option 1 for demo license or option 2 for individual license.

### Manual Generation

You can manually create keys using this format:

**Demo License**: 
```
DEMO-XXXXX-XXXXX-XXXXX
```

**Individual License**:
```
XXXXX-XXXXX-XXXXX-XXXXX
```

Where each segment is 5 characters (A-Z, 0-9).

## Quick Test Keys

Here are some ready-to-use test keys:

### Demo License (Lifetime Pro):
```
DEMO-TEST-LICENSE-KEY
```

### Individual License (1 year):
```
TEST1-23456-ABCDE-FGHIJ
ABC12-DEF34-GHI56-JKL78
```

## How to Activate

1. Open EchoTune
2. Go to Settings
3. Navigate to the License section
4. Enter your license key
5. Click "Activate License"

The license will be stored securely in your macOS Keychain.

## Notes

- License keys are validated locally (no server connection required for testing)
- Demo licenses never expire and provide Pro tier features
- Individual licenses are valid for 1 year from activation date
- License information is stored securely in the macOS Keychain





