import json
import re # For regular expressions (used for price cleaning and unit extraction)
import uuid # For generating unique IDs if no other logic is preferred

def extract_unit_from_name(product_name):
    """
    Attempts to extract common units from the product name.
    This is a basic implementation and might need to be expanded.
    Examples: "14 oz", "4 count", "Each", "1 lb"
    """
    if not product_name:
        return None

    # Regex to find patterns like "16 oz", "1 lb", "4 count", "Each"
    # It looks for a number (optional) followed by a space (optional) and common units.
    # It also handles "Each" as a standalone unit.
    match = re.search(
        r"(\b\d+(\.\d+)?\s*(oz|fl oz|lb|lbs|g|kg|ml|l|ct|count)\b|\bEach\b)",
        product_name,
        re.IGNORECASE
    )
    if match:
        return match.group(0).strip() # Return the found unit string

    # Fallback for simple "Each" if not caught by the more complex regex
    if "each" in product_name.lower():
        return "Each"

    return None # Or return a default like "N/A" or an empty string

def transform_product_data(source_file_path, output_file_path, store_id, category_name, sub_category_name):
    """
    Transforms product data from the older Aldi/Walmart structure to the newer,
    more detailed structure.

    Args:
        source_file_path (str): Path to the source JSON file.
        output_file_path (str): Path to save the transformed JSON file.
        store_id (str): The store ID (e.g., "aldi", "walmart").
        category_name (str): The main category for these products.
        sub_category_name (str): The sub-category for these products.
    """
    try:
        with open(source_file_path, 'r', encoding='utf-8') as f:
            source_data = json.load(f)
    except FileNotFoundError:
        print(f"Error: The file '{source_file_path}' was not found.")
        return
    except json.JSONDecodeError:
        print(f"Error: Could not decode JSON from '{source_file_path}'. Ensure it's valid.")
        return
    except Exception as e:
        print(f"An unexpected error occurred while reading '{source_file_path}': {e}")
        return

    transformed_products = []
    product_counter = 1

    if not isinstance(source_data, list):
        print(f"Error: Expected a list of products in '{source_file_path}', but got {type(source_data)}.")
        return

    for i, product in enumerate(source_data):
        try:
            if not isinstance(product, dict):
                print(f"Warning: Skipping an item that is not a product dictionary: {product}")
                continue

            original_name = product.get("product name")
            original_description = product.get("product description")

            # Generate a unique ID
            # Using a combination of store, category, and a counter for uniqueness within the file
            generated_id = f"{store_id.lower().replace(' ', '_')}_{sub_category_name.lower().replace(' ', '_')}_{product_counter:03d}"
            product_counter += 1

            # Clean and convert price
            price_str = product.get("price", "0")
            cleaned_price_str = re.sub(r"[^0-9.]", "", str(price_str))
            numeric_price = 0.0
            try:
                numeric_price = float(cleaned_price_str) if cleaned_price_str else 0.0
            except ValueError:
                print(f"Warning: Could not convert price '{price_str}' to number for product: {original_name}. Using 0.0.")

            # Attempt to extract unit from name
            extracted_unit = extract_unit_from_name(original_name)

            transformed_product = {
                "id": generated_id,
                "name": original_name,
                "imageUrl": product.get("imageUrl"),
                "description": original_description,
                "benefits": None,  # Benefits are not typically in the older format
                "price": numeric_price,
                "unit": extracted_unit, # Use extracted unit, or None if not found
                "storeId": store_id,
                "category": category_name,
                "subCategory": sub_category_name
            }
            transformed_products.append(transformed_product)

        except Exception as e:
            print(f"An unexpected error occurred while transforming product: {product.get('product name', 'Unknown Product')}. Error: {e}")
            continue

    try:
        with open(output_file_path, 'w', encoding='utf-8') as f:
            json.dump(transformed_products, f, indent=2, ensure_ascii=False)
        print(f"Transformation complete. Transformed data saved to: '{output_file_path}'")
    except Exception as e:
        print(f"An unexpected error occurred while writing to '{output_file_path}': {e}")

if __name__ == '__main__':
    # --- IMPORTANT: CONFIGURE THESE BEFORE RUNNING ---

    # Example for processing 'walmart_celery.json':
    # You would run this script multiple times, once for each Aldi/Walmart product file,
    # changing these parameters each time.

    # --- Configuration for the current file to process ---
    # 1. Set the input file path
    current_source_file = "aldi_fresh_beef.json"  # Or "aldi_bakery_desserts.json", etc.

    # 2. Set the desired output file path (the transformed file)
    current_output_file = "aldi_fresh_beef1.json" # Change this to match the input

    # 3. Set the store ID for the products in this file
    current_store_id = "aldi"  # Or "aldi"

    # 4. Set the main category for the products in this file
    current_category_name = "Fresh Meat & Seafood" # e.g., "Bakery & Bread" for aldi_bakery_desserts

    # 5. Set the sub-category for the products in this file
    current_sub_category_name = "Meat & Seafood" # e.g., "Bakery Desserts" for aldi_bakery_desserts
    # --- End Configuration ---

    print(f"Processing: {current_source_file}")
    print(f"Store ID: {current_store_id}, Category: {current_category_name}, SubCategory: {current_sub_category_name}")

    transform_product_data(
        current_source_file,
        current_output_file,
        current_store_id,
        current_category_name,
        current_sub_category_name
    )

    # --- To process another file, you would change the variables above and run again ---
    # Example for Aldi desserts:
    # current_source_file = "aldi_bakery_desserts.json"
    # current_output_file = "transformed_aldi_bakery_desserts.json"
    # current_store_id = "aldi"
    # current_category_name = "Bakery & Bread" # Or your preferred category name
    # current_sub_category_name = "Bakery Desserts"
    # transform_product_data(current_source_file, current_output_file, current_store_id, current_category_name, current_sub_category_name)
