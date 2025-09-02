
from pathlib import Path
from modules.rename_file import rename_file,rename_encrypted_to_decrypted,rename_encrypted_to_decrypted_with_dir
from modules.timer import start_timer, stop_timer
from modules.threads import threaded_encrypt_folder, threaded_decrypt_folder, get_optimal_thread_count
# key, key_file_path , encrypted_byte arent used but leave it
def encrypt_file(input_file_path, output_file_path=None, key=None, key_file_path=None, encrypted_bytes=None, overwrite=False, suppress_output=False):
    # START TIMER
    start_time = start_timer()

    
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


    # ENCRYPT 
    void_data = ''
    void_data = void_data.encode('utf-8')

    # WRITE BACK
    with open(output_file_path, 'wb') as outfile:
        outfile.write(void_data)  # Overwrite with void data

    # END TIMER
    end_time = stop_timer(start_time)

    if not suppress_output:
        print(f"Encryption time: {end_time:.2f} seconds")

def encrypt_folder(folder_path, output_folder_path=None, key=None, key_file_path=None, encrypted_bytes=None, overwrite=False, use_threading=True, max_workers=None):
    """
    VOID all files in a folder and its subfolders using the same key
    """
    # START TIMER
    start_time = start_timer()
    
    # Determine thread count
    if max_workers is None:
        max_workers = get_optimal_thread_count()
    
    # IF MULTITHREADING ALLOWED
    if use_threading:
        print(f"Using multithreading with {max_workers} workers")
        key, encrypted_count, failed_count = threaded_encrypt_folder(
            folder_path=folder_path,
            encrypt_func=encrypt_file,
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
            if file_path.is_file():
                all_files.append(file_path)
        
        if not all_files:
            print("No files found to void")
            return key
        
        print(f"Found {len(all_files)} files to void (single-threaded)")
        encrypted_count = 0
        failed_count = 0
        
        # VOID EACH FILE
        for file_path in all_files:
            try:
                print(f"VOIDING: {file_path}")
                
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
                    overwrite=overwrite
                )
                encrypted_count += 1
                
            except Exception as e:
                print(f"Failed to encrypt {file_path}: {e}")
                failed_count += 1
    
    # END TIMER
    end_time = stop_timer(start_time)
    print(f"\nFolder encryption completed in {end_time:.2f} seconds")
    print(f"Encrypted: {encrypted_count} files")
    if failed_count > 0:
        print(f"Failed: {failed_count} files")
    
    return key
def test_encrypt_file():
    input_file = "files/testfiles/JOB.png"
    output_file = "files/encryptedfiles"
    encrypt_file(input_file, output_file, overwrite=False)

