from pathlib import Path
import random
import string
#change extension of a file + name

def random_string(length):
    return ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(length))

def rename_file(original_path, new_ext):
    # First half of name
    first_half = "NEKO"
    #second half
    second_half = random_string(12)
    original_path = Path(original_path)
    #third half - original file name
    third_half = original_path.stem
    #forth half - file org suffix
    forth_half = original_path.suffix
    #new suffix / .ext
    new_suffix = new_ext
    new_file_path = original_path.with_name(f"{first_half}_{second_half}_{third_half}_{forth_half}{new_suffix}")
    #rename
    original_path.rename(new_file_path)

    
def rename_encrypted_to_decrypted_with_dir(encrypted_path, output_dir=None):

    encrypted_path = Path(encrypted_path)
    
    # Parse the encrypted filename
    filename_parts = encrypted_path.stem.split('_')
    
    if len(filename_parts) >= 4 and filename_parts[0] == "NEKO":
        # Format: NEKO_randomid_originalname_extension.neko
        original_name = filename_parts[2]
        original_extension = filename_parts[3]
        
        # Handle cases where extension might have dots (like .tar.gz)
        if len(filename_parts) > 4:
            # Join any additional parts that might be part of the extension
            additional_parts = filename_parts[4:]
            original_extension = original_extension + '.' + '.'.join(additional_parts)
        
        # Reconstruct original filename
        if original_extension.startswith('.'):
            original_filename = f"{original_name}{original_extension}"
        else:
            original_filename = f"{original_name}.{original_extension}"
    else:
        # Fallback for non-standard naming
        original_filename = f"decrypted_{encrypted_path.stem}"
    
    # Determine output path
    if output_dir:
        output_path = Path(output_dir) / original_filename
    else:
        output_path = encrypted_path.parent / original_filename
    
    return str(output_path)
def rename_encrypted_to_decrypted(encrypted_filename):
    """
    Extract just the original filename from encrypted filename without path operations
    Example: NEKO_igj72mjmnzbl_neko_kimono_.jpeg.neko -> neko_kimono.jpeg
    """
    encrypted_path = Path(encrypted_filename)
    filename_parts = encrypted_path.stem.split('_')
    
    if len(filename_parts) >= 4 and filename_parts[0] == "NEKO":
        # Format: NEKO_randomid_originalname_extension
        original_name = filename_parts[2]
        original_extension = filename_parts[3]
        
        # Handle multi-part extensions
        if len(filename_parts) > 4:
            additional_parts = filename_parts[4:]
            original_extension = original_extension + '.' + '.'.join(additional_parts)
        
        # Reconstruct original filename
        if original_extension.startswith('.'):
            return f"{original_name}{original_extension}"
        else:
            return f"{original_name}.{original_extension}"
    else:
        # Fallback
        return f"decrypted_{encrypted_path.stem}"