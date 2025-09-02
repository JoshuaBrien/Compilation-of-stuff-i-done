from ciphers.ChaCha20 import encrypt_file as chacha_encrypt, decrypt_file as chacha_decrypt, load_key_from_pem as chacha_load_key, encrypt_folder as chacha_encrypt_folder, decrypt_folder as chacha_decrypt_folder
from ciphers.AES import encrypt_file as aes_encrypt, decrypt_file as aes_decrypt, load_key_from_pem as aes_load_key, encrypt_folder as aes_encrypt_folder, decrypt_folder as aes_decrypt_folder
from ciphers.VOID import encrypt_file as void_encrypt, encrypt_folder as void_encrypt_folder
from pathlib import Path

#GLOBAL VARS
ciphers_list = ["AES","ChaCha20"]
current_key = None  # Cache the current key
current_key_file = None  # Track which key file is loaded
current_encrypted_bytes = None
#CONFIG VARS:
overwrite = False #overwrite file? -> if yes, it will replace the file
current_cipher = "ChaCha20" #default cipher
current_decrypted_output_path = "files/decryptedfiles/"
current_encrypted_output_path = "files/encryptedfiles/"
menu = True #show menu? -> always be true

def get_cipher_functions():
    """Get the appropriate functions based on current cipher"""
    if current_cipher == "AES":
        return aes_encrypt, aes_decrypt, aes_load_key, aes_encrypt_folder, aes_decrypt_folder
    else:  # ChaCha20
        return chacha_encrypt, chacha_decrypt, chacha_load_key, chacha_encrypt_folder, chacha_decrypt_folder

def load_or_get_key(key_file_path):
    """Load key from file or return cached key if same file"""
    global current_key, current_key_file
    
    if current_key_file == key_file_path and current_key is not None:
        print(f"Using cached key for {key_file_path}")
        return current_key
    
    # Load new key
    _, _, load_key_func, _, _ = get_cipher_functions()
    try:
        current_key = load_key_func(key_file_path)
        current_key_file = key_file_path
        print(f"Loaded key from {key_file_path}")
        return current_key
    except FileNotFoundError:
        print(f"Key file {key_file_path} not found!")
        return None

def menu():
    #GET config vars
    global overwrite, menu, current_cipher, current_key, current_key_file, current_encrypted_output_path, current_decrypted_output_path,current_encrypted_bytes
    while menu:
        key_status = f"Key loaded: {current_key_file}" if current_key else "No key loaded"
        print(f"NEKOCRYPTER\n[0] EXIT \n[O] OVERWRITE: {overwrite} WILL OVERWRITE ENCRYPT + DECRYPT OUTPUT PATHS\n[C] CIPHER: {current_cipher}\n[B] Configure bytes to encrypt: {current_encrypted_bytes}\n[1] Configure encrypt output path: {current_encrypted_output_path}\n[2] Configure decrypt output path: {current_decrypted_output_path}")
        print(f"[3] ENCRYPT \n[4] DECRYPT\n[5] LOAD KEY\n[6] CLEAR KEY\n[V] VOID FILE\n[0] EXIT\n{key_status} ")
        choice = input("Enter your choice: ")

        if choice == "O":
            #TOGGLE OVERWRITE
            overwrite = True if not overwrite else False
        elif choice == "C":
            # Switch cipher
            current_idx = ciphers_list.index(current_cipher)
            current_cipher = ciphers_list[(current_idx + 1) % len(ciphers_list)]
            # Clear cached key when switching ciphers
            current_key = None
            current_key_file = None
            print(f"Switched to {current_cipher}")
        elif choice == "B":
            current_encrypted_bytes = int(input("Enter the new number of bytes to encrypt: "))
        elif choice == "1":
            current_encrypted_output_path = input("Enter the new path for encrypted output files: ")
        elif choice == "2":
            current_decrypted_output_path = input("Enter the new path for decrypted output files: ")
        elif choice == "3":
            encrypt_func, _, _, encrypt_folder_func, _ = get_cipher_functions()
            #GET FILE OR FOLDER TO ENCRYPT
            input_path = input("Enter the path of the file or folder to encrypt: ")
            input_path_obj = Path(input_path)

            # USE EXISTING KEY IF ALREADY LOADED! 
            if current_key:
                key = current_key
                key_file_path = current_key_file
            else:
                key = None
                key_file_path = f"files/keys/NEKO{current_cipher}_key.pem"

            # CHECK IF INPUT IS FILE OR FOLDER
            if input_path_obj.is_dir():
                print(f"Detected folder: {input_path}")
                # CRITICAL : OVERWRITE?
                if overwrite:
                    print(f"OVERWRITE MODE ENABLED! WILL OVERWRITE FILES IN PLACE")
                    key = encrypt_folder_func(input_path, key=key, key_file_path=key_file_path, encrypted_bytes=current_encrypted_bytes, overwrite=overwrite)
                else:
                    #DISPLAY OUTPUT PATH
                    print(f"Current encrypted output path is {current_encrypted_output_path}")
                    key = encrypt_folder_func(input_path, output_folder_path=current_encrypted_output_path, key=key, key_file_path=key_file_path, encrypted_bytes=current_encrypted_bytes, overwrite=overwrite)
            elif input_path_obj.is_file():
                print(f"Detected file: {input_path}")
                # CRITICAL : OVERWRITE?
                if overwrite:
                    print(f"OVERWRITE MODE ENABLED! WILL OVERWRITE FILES")
                    key = encrypt_func(input_path, key=key, key_file_path=key_file_path, encrypted_bytes=current_encrypted_bytes,overwrite=overwrite)
                else:
                    #DISPLAY OUTPUT PATH
                    print(f"Current encrypted output path is {current_encrypted_output_path}")
                    key = encrypt_func(input_path, output_file_path=current_encrypted_output_path, key=key, key_file_path=key_file_path, encrypted_bytes=current_encrypted_bytes, overwrite=overwrite)
            else:
                print(f"Error: {input_path} is not a valid file or folder!")
                continue

            if key:
                current_key = key
                current_key_file = key_file_path
                print(f"Encryption completed successfully!")
            
        elif choice == "4":
            _, decrypt_func, _, _, decrypt_folder_func = get_cipher_functions()
            # GET FILE OR FOLDER TO DECRYPT
            encrypted_path = input("Enter the path of the file or folder to decrypt: ")
            encrypted_path_obj = Path(encrypted_path)
            
            # CHECK IF KEY IS LOADED OR LOAD ONE
            if current_key:
                key = current_key
            else:
                key_file = input("Enter the path of the key file: ")
                key = load_or_get_key(key_file)
            
            if not key:
                print("No valid key available for decryption!")
                continue

            # CHECK IF INPUT IS FILE OR FOLDER
            if encrypted_path_obj.is_dir():
                print(f"Detected folder: {encrypted_path}")
                # CRITICAL : OVERWRITE ?
                if overwrite:
                    print(f"OVERWRITE MODE ENABLED! WILL OVERWRITE FILES IN PLACE")
                    result = decrypt_folder_func(encrypted_path, key=key, encrypted_bytes=current_encrypted_bytes,overwrite=overwrite)
                else:
                    print(f"Current decrypted output path is {current_decrypted_output_path}")
                    result = decrypt_folder_func(encrypted_path, key=key, output_folder_path=current_decrypted_output_path, encrypted_bytes=current_encrypted_bytes, overwrite=overwrite)

                if result is not None and result > 0:
                    print(f"Folder decryption completed successfully!")
                else:
                    print("Folder decryption failed or no files were decrypted!")
                    
            elif encrypted_path_obj.is_file():
                print(f"Detected file: {encrypted_path}")
                # CRITICAL : OVERWRITE ?
                if overwrite:
                    print(f"OVERWRITE MODE ENABLED! WILL OVERWRITE FILES")
                    decrypted_path = decrypt_func(encrypted_path, key=key, encrypted_bytes=current_encrypted_bytes,overwrite=overwrite)
                else:
                    print(f"Current decrypted output path is {current_decrypted_output_path}")
                    decrypted_path = decrypt_func(encrypted_path, output_file_path=current_decrypted_output_path, key=key, encrypted_bytes=current_encrypted_bytes, overwrite=overwrite)
                
                if decrypted_path:
                    print(f"File decrypted successfully!")
                    print(f"Decrypted file saved to: {decrypted_path}")
                else:
                    print("File decryption failed!")
            else:
                print(f"Error: {encrypted_path} is not a valid file or folder!")

        elif choice == "5":
            # Load key manually
            key_file = input("Enter the path of the key file: ")
            key = load_or_get_key(key_file)
            if key:
                print("Key loaded successfully!")
        
        elif choice == "6":
            # Clear cached key
            current_key = None
            current_key_file = None
            print("Key cache cleared.")
        elif choice == "V":
            #GET FILE OR FOLDER TO VOID
            input_path = input("Enter the path of the file or folder to void: ")
            input_path_obj = Path(input_path)

            # CHECK IF INPUT IS FILE OR FOLDER
            # FOLDER
            if input_path_obj.is_dir():
                print(f"Detected folder: {input_path}")
                # CRITICAL : OVERWRITE?
                if overwrite:
                    print(f"OVERWRITE MODE ENABLED! WILL VOID FILES IN PLACE")
                    key = void_encrypt_folder(input_path,overwrite=overwrite)
                else:
                    #DISPLAY OUTPUT PATH
                    print(f"Current void output path is {current_encrypted_output_path}")
                    key = void_encrypt_folder(input_path, output_folder_path=current_encrypted_output_path, overwrite=overwrite)
            # INDV FILE
            elif input_path_obj.is_file():
                print(f"Detected file: {input_path}")
                # CRITICAL : OVERWRITE?
                if overwrite:
                    print(f"OVERWRITE MODE ENABLED! WILL OVERWRITE FILES")
                    key =  void_encrypt(input_path,overwrite=overwrite)
                else:
                    #DISPLAY OUTPUT PATH
                    print(f"Current void output path is {current_encrypted_output_path}")
                    key = void_encrypt(input_path, output_file_path=current_encrypted_output_path, overwrite=overwrite)
            else:
                print(f"Error: {input_path} is not a valid file or folder!")
                continue
            print(f"Void operation completed successfully!")

        elif choice == "0":
            print("Exiting...")
            break
        else:
            print("Invalid choice.")

if __name__ == "__main__":
    menu()