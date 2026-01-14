#!/usr/bin/env python3
"""
JSON Schema validator for Helm values.yaml
Usage: python3 validate-schema.py <values-file> <schema-file>
"""

import sys
import json
import yaml
from pathlib import Path

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 validate-schema.py <values-file> <schema-file>")
        sys.exit(1)

    values_file = Path(sys.argv[1])
    schema_file = Path(sys.argv[2])

    # Check files exist
    if not values_file.exists():
        print(f"❌ Error: Values file not found: {values_file}")
        sys.exit(1)

    if not schema_file.exists():
        print(f"❌ Error: Schema file not found: {schema_file}")
        sys.exit(1)

    try:
        # Import jsonschema (may not be installed)
        try:
            from jsonschema import validate, ValidationError, Draft7Validator
        except ImportError:
            print("❌ Error: jsonschema library not installed")
            print("   Install with: pip3 install jsonschema")
            sys.exit(1)

        # Load schema
        with open(schema_file, 'r') as f:
            schema = json.load(f)

        # Load values
        with open(values_file, 'r') as f:
            values = yaml.safe_load(f)

        # Validate
        validator = Draft7Validator(schema)
        errors = list(validator.iter_errors(values))

        if errors:
            print(f"❌ Schema validation failed for {values_file.name}")
            print(f"   Found {len(errors)} error(s):\n")

            for i, error in enumerate(errors, 1):
                path = " → ".join(str(p) for p in error.path) if error.path else "(root)"
                print(f"   [{i}] Path: {path}")
                print(f"       Error: {error.message}")
                if error.validator:
                    print(f"       Validator: {error.validator}")
                print()

            sys.exit(1)
        else:
            print(f"✅ Schema validation passed for {values_file.name}")
            sys.exit(0)

    except yaml.YAMLError as e:
        print(f"❌ Error parsing YAML file: {e}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ Error parsing JSON schema: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
