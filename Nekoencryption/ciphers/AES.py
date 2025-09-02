from Crypto.Cipher import AES
import os
from Crypto.Random import get_random_bytes
from Crypto.Util.Padding import pad,unpad
import base64
from pathlib import Path

from modules.rename_file import rename_file,rename_encrypted_to_decrypted,rename_encrypted_to_decrypted_with_dir
from modules.timer import start_timer, stop_timer
from modules.threads import threaded_encrypt_folder, threaded_decrypt_folder, get_optimal_thread_count

# AES - IV of 16
def generate_key():
    return get_random_bytes(32)


def encrypt_file(input_file_path, output_file_path=None, key=None, key_file_path=None, encrypted_bytes=None, overwrite=False, suppress_output=False):
    # START TIMER
    start_time = start_timer()

    # IF NO KEY
    key_was_generated = False
    if key is None:
        key = generate_key()
        key_was_generated = True

    # Generate IV (16 bytes for AES)
    iv = get_random_bytes(16)
    AEScipher = AES.new(key, AES.MODE_CBC, iv)

    # CRITICAL : OVERWRITE?
    input_path = Path(input_file_path)
    
    if overwrite:
        # In overwrite mode, replace the original file
        output_file_path = input_path.parent / input_path.name
    else:
        # In normal mode, create output directory and place file there
        encrypted_dir = Path(output_file_path)
        encrypted_dir.mkdir(exist_ok=True)
        output_file_path = encrypted_dir / input_path.name

    # READ FILE __ BYTES
    with open(input_file_path, 'rb') as infile:
        if encrypted_bytes is not None:  # IF SPECIFIED TO ENCRYPT __ BYTES
            data_to_encrypt = infile.read(encrypted_bytes)
            remaining_data = infile.read()
        else:
            data_to_encrypt = infile.read()  # ELSE DO ALL
            remaining_data = b''

    # ENCRYPT 
    encrypted_data = AEScipher.encrypt(pad(data_to_encrypt,AES.block_size))
    

    # WRITE BACK
    with open(output_file_path, 'wb') as outfile:
        outfile.write(iv + encrypted_data)  # Store IV + encrypted data
        if remaining_data:
            outfile.write(remaining_data)
    
    # RENAME
    rename_file(str(output_file_path), '.neko')

    # END TIMER
    end_time = stop_timer(start_time)
    if not suppress_output:
        print(f"Encryption time: {end_time:.2f} seconds")

    # SAVE KEY ONLY IF NEW KEY WAS GENERATED
    if key_file_path and key_was_generated:
        if not Path(key_file_path).exists():
            save_key_to_pem(key, key_file_path)
            if not suppress_output:
                print(f"Key saved to: {key_file_path}")
        elif not overwrite:
            if not suppress_output:
                response = input(f"Key file {key_file_path} already exists. Overwrite? (y/n): ")
                if response.lower() in ['y', 'yes']:
                    save_key_to_pem(key, key_file_path)
                    print(f"Key saved to: {key_file_path}")
                else: 
                    print("Key file not saved.")
        else:
            # If overwrite is True, save without asking
            save_key_to_pem(key, key_file_path)
            if not suppress_output:
                print(f"Key saved to: {key_file_path}")
    
    return key

def encrypt_folder(folder_path, output_folder_path=None, key=None, key_file_path=None, encrypted_bytes=None, overwrite=False, use_threading=True, max_workers=None):
    """
    Encrypt all files in a folder and its subfolders using the same key
    """
    # START TIMER
    start_time = start_timer()
    
    # GENERATE KEY IF NONE
    key_was_generated = False
    if key is None:
        key = generate_key()
        key_was_generated = True
    
    # Determine thread count
    if max_workers is None:
        max_workers = get_optimal_thread_count()
    
    # IF MULTITHREADING ALLOWED
    if use_threading:
        print(f"Using multithreading with {max_workers} workers")
        key, encrypted_count, failed_count = threaded_encrypt_folder(
            folder_path=folder_path,
            encrypt_func=encrypt_file,
            output_folder_path=output_folder_path,
            key=key,
            encrypted_bytes=encrypted_bytes,
            overwrite=overwrite,
            max_workers=max_workers
        )
    else:
        # Original single-threaded implementation
        folder_path = Path(folder_path)
        if not folder_path.exists() or not folder_path.is_dir():
            print(f"Error: {folder_path} is not a valid directory")
            return None
        
        # GET ALL FILES RECURSIVELY
        all_files = []
        for file_path in folder_path.rglob('*'):
            if file_path.is_file() and not file_path.name.endswith('.neko'):
                all_files.append(file_path)
        
        if not all_files:
            print("No files found to encrypt")
            return key
        
        print(f"Found {len(all_files)} files to encrypt (single-threaded)")
        encrypted_count = 0
        failed_count = 0
        
        # ENCRYPT EACH FILE
        for file_path in all_files:
            try:
                print(f"Encrypting: {file_path}")
                
                # MAINTAIN FOLDER STRUCTURE
                if overwrite:
                    file_output_path = None
                else:
                    if output_folder_path:
                        relative_path = file_path.relative_to(folder_path)
                        file_output_dir = Path(output_folder_path) / relative_path.parent
                        file_output_dir.mkdir(parents=True, exist_ok=True)
                        file_output_path = str(file_output_dir)
                    else:
                        file_output_path = "files/encryptedfiles/"
                
                # ENCRYPT SINGLE FILE
                encrypt_file(
                    input_file_path=str(file_path),
                    output_file_path=file_output_path,
                    key=key,
                    key_file_path=None,
                    encrypted_bytes=encrypted_bytes,
                    overwrite=overwrite
                )
                encrypted_count += 1
                
            except Exception as e:
                print(f"Failed to encrypt {file_path}: {e}")
                failed_count += 1
    
    # SAVE KEY ONLY IF NEW KEY WAS GENERATED
    if key_file_path and key_was_generated:
        if not Path(key_file_path).exists():
            save_key_to_pem(key, key_file_path)
            print(f"Key saved to: {key_file_path}")
        elif not overwrite:
            response = input(f"Key file {key_file_path} already exists. Overwrite? (y/n): ")
            if response.lower() in ['y', 'yes']:
                save_key_to_pem(key, key_file_path)
                print(f"Key saved to: {key_file_path}")
        else:
            save_key_to_pem(key, key_file_path)
            print(f"Key saved to: {key_file_path}")
    
    # END TIMER
    end_time = stop_timer(start_time)
    print(f"\nFolder encryption completed in {end_time:.2f} seconds")
    print(f"Encrypted: {encrypted_count} files")
    if failed_count > 0:
        print(f"Failed: {failed_count} files")
    
    return key

def decrypt_file(encrypted_file_path, key, output_file_path=None, encrypted_bytes=None, overwrite=False, suppress_output=False):
    #START TIMER
    start_time = start_timer()
    encrypted_path = Path(encrypted_file_path)

    #GET KEY + NONCE
    with open(encrypted_file_path, 'rb') as infile:
        nonce = infile.read(16)  # Read 16-byte IV /nonce
        
        #READ ONLY __ BYTES IF SPECIFIED
        if encrypted_bytes is not None:
            encrypted_data = infile.read(encrypted_bytes)
            remaining_data = infile.read()
        else:
            encrypted_data = infile.read()
            remaining_data = b''
    
    # CREATE CIPHER -> same key, iv and mode
    AEScipher = AES.new(key=key, mode=AES.MODE_CBC, iv=nonce)

    #DECRYPT
    decrypted_data = unpad(AEScipher.decrypt((encrypted_data,AES.block_size)))

    # CRITICAL : OVERWRITE?
    if overwrite:
        # Get original filename for overwrite mode
        filename_parts = encrypted_path.stem.split('_')
        if len(filename_parts) >= 4 and filename_parts[0] == "NEKO":
            # Format: NEKO_randomid_originalname_extension
            # Join everything from index 2 to second-to-last as the original name
            original_name = '_'.join(filename_parts[2:-1])  # Join all parts except first 2 and last
            original_extension = filename_parts[-1]  # Last part is the extension
            
            # Reconstruct original filename
            if original_extension.startswith('.'):
                original_filename = f"{original_name}{original_extension}"
            else:
                original_filename = f"{original_name}.{original_extension}"
        else:
            original_filename = f"decrypted_{encrypted_path.stem}"
        
        output_file_path = encrypted_path.parent / original_filename
    else:
        # Place decrypted file in decryptedfiles directory (normal mode)
        filename_parts = encrypted_path.stem.split('_')
        if len(filename_parts) >= 4 and filename_parts[0] == "NEKO":
            # Format: NEKO_randomid_originalname_extension
            # Join everything from index 2 to second-to-last as the original name
            original_name = '_'.join(filename_parts[2:-1])  # Join all parts except first 2 and last
            original_extension = filename_parts[-1]  # Last part is the extension
            
            # Reconstruct original filename
            if original_extension.startswith('.'):
                original_filename = f"{original_name}{original_extension}"
            else:
                original_filename = f"{original_name}.{original_extension}"
        else:
            original_filename = f"decrypted_{encrypted_path.stem}"

        if output_file_path:
            decrypted_dir = Path(output_file_path)
        else:
            decrypted_dir = Path("decryptedfiles")
        decrypted_dir.mkdir(exist_ok=True)
        output_file_path = decrypted_dir / original_filename

    # Confirm overwrite if file exists
    if Path(output_file_path).exists() and not overwrite and not suppress_output:
        response = input(f"Decrypted file {output_file_path} already exists. Overwrite? (y/n): ")
        if response.lower() not in ['y', 'yes']:
            print("Decryption cancelled.")
            return None

    # Write the file (this will overwrite if file exists and overwrite=True or user confirmed)
    with open(output_file_path, 'wb') as outfile:
        outfile.write(decrypted_data)
        if remaining_data:
            outfile.write(remaining_data)

    # HANDLE OVERWRITE RENAMING
    if overwrite:
        # Delete the original encrypted file since we've written to the new location
        encrypted_path.unlink()

    end_time = stop_timer(start_time)
    if not suppress_output:
        print(f"Decryption time: {end_time:.2f} seconds")

    return str(output_file_path)

def decrypt_folder(folder_path, key, output_folder_path=None, encrypted_bytes=None, overwrite=False, use_threading=True, max_workers=None):

    # START TIMER
    start_time = start_timer()
    
    # Determine thread count
    if max_workers is None:
        max_workers = get_optimal_thread_count()
    
    if use_threading:
        print(f"Using multithreading with {max_workers} workers")
        decrypted_count, failed_count = threaded_decrypt_folder(
            folder_path=folder_path,
            decrypt_func=decrypt_file,
            key=key,
            output_folder_path=output_folder_path,
            encrypted_bytes=encrypted_bytes,
            overwrite=overwrite,
            max_workers=max_workers
        )
    else:
        # Original single-threaded implementation
        folder_path = Path(folder_path)
        if not folder_path.exists() or not folder_path.is_dir():
            print(f"Error: {folder_path} is not a valid directory")
            return None
        
        # GET ALL .NEKO FILES RECURSIVELY
        all_neko_files = []
        for file_path in folder_path.rglob('*.neko'):
            if file_path.is_file():
                all_neko_files.append(file_path)
        
        if not all_neko_files:
            print("No .neko files found to decrypt")
            return None
        
        print(f"Found {len(all_neko_files)} .neko files to decrypt (single-threaded)")
        decrypted_count = 0
        failed_count = 0
        
        # DECRYPT EACH FILE
        for file_path in all_neko_files:
            try:
                print(f"Decrypting: {file_path}")
                
                # MAINTAIN FOLDER STRUCTURE
                if overwrite:
                    file_output_path = None
                else:
                    if output_folder_path:
                        relative_path = file_path.relative_to(folder_path)
                        file_output_dir = Path(output_folder_path) / relative_path.parent
                        file_output_dir.mkdir(parents=True, exist_ok=True)
                        file_output_path = str(file_output_dir)
                    else:
                        file_output_path = "files/decryptedfiles/"
                
                # DECRYPT SINGLE FILE
                result = decrypt_file(
                    encrypted_file_path=str(file_path),
                    key=key,
                    output_file_path=file_output_path,
                    encrypted_bytes=encrypted_bytes,
                    overwrite=overwrite
                )
                
                if result:
                    decrypted_count += 1
                else:
                    failed_count += 1
                    
            except Exception as e:
                print(f"Failed to decrypt {file_path}: {e}")
                failed_count += 1
    
    # END TIMER
    end_time = stop_timer(start_time)
    print(f"\nFolder decryption completed in {end_time:.2f} seconds")
    print(f"Decrypted: {decrypted_count} files")
    if failed_count > 0:
        print(f"Failed: {failed_count} files")
    
    return decrypted_count

def save_key_to_pem(key, key_file_path):
    key_b64 = base64.b64encode(key).decode('utf-8')
    pem_content = f"-----BEGIN AES KEY-----\n"
    for i in range(0, len(key_b64), 64):
        pem_content += key_b64[i:i+64] + "\n"
    pem_content += "-----END AES KEY-----\n"
    
    with open(key_file_path, 'w') as key_file:
        key_file.write(pem_content)

def load_key_from_pem(key_file_path):
    with open(key_file_path, 'r') as key_file:
        pem_content = key_file.read()
    
    lines = pem_content.strip().split('\n')
    key_b64 = ''.join(line for line in lines if not line.startswith('-----'))
    key = base64.b64decode(key_b64)
    return key