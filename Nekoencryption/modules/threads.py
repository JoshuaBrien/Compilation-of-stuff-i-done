import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
import time
import os
import sys
from pathlib import Path

class ThreadSafeProgress:
    def __init__(self, total_files):
        self.total_files = total_files
        self.completed = 0
        self.failed = 0
        self.lock = threading.Lock()
        self.start_time = time.time()
        
    def update(self, success=True):
        with self.lock:
            if success:
                self.completed += 1
            else:
                self.failed += 1
            
            current = self.completed + self.failed
            percent = (current / self.total_files) * 100
            elapsed_time = time.time() - self.start_time
            
            eta = 0
            if current < self.total_files and current > 0:
                avg_time = elapsed_time / current
                eta = avg_time * (self.total_files - current)
            
            #PROGRESS MESSAGE
            print(f"\rProgress: {current}/{self.total_files} ({percent:.1f}%) | "
                  f"Success: {self.completed} | Failed: {self.failed} | "
                  f"ETA: {eta:.1f}s", end='', flush=True)
            
            if current == self.total_files:
                print()  # Final newline

def process_file_worker(file_info, process_func, key, **kwargs):

    file_path, output_path = file_info
    
    try:
        # Call the function with a flag to suppress output
        result = process_func(
            input_file_path=str(file_path),
            output_file_path=output_path,
            key=key,
            key_file_path=None,
            suppress_output=True,  # Add this flag
            **kwargs
        )
        return True, file_path, result
    except Exception as e:
        return False, file_path, str(e)

def decrypt_file_worker(file_info, decrypt_func, key, **kwargs):

    file_path, output_path = file_info
    
    try:
        result = decrypt_func(
            encrypted_file_path=str(file_path),
            key=key,
            output_file_path=output_path,
            suppress_output=True, 
            **kwargs
        )
        return True, file_path, result
    except Exception as e:
        return False, file_path, str(e)

def threaded_encrypt_folder(folder_path, encrypt_func, output_folder_path=None, key=None, 
                          encrypted_bytes=None, overwrite=False, max_workers=4):

    folder_path = Path(folder_path)
    if not folder_path.exists() or not folder_path.is_dir():
        print(f"Error: {folder_path} is not a valid directory")
        return None, 0, 0

    file_tasks = []
    for file_path in folder_path.rglob('*'):
        if file_path.is_file() and not file_path.name.endswith('.neko'):
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
            
            file_tasks.append((file_path, file_output_path))
    
    if not file_tasks:
        print("No files found to encrypt")
        return key, 0, 0
    
    print(f"Found {len(file_tasks)} files to encrypt using {max_workers} threads")
    
    progress = ThreadSafeProgress(len(file_tasks))
    encrypted_count = 0
    failed_count = 0
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all tasks
        future_to_file = {
            executor.submit(
                process_file_worker,
                file_info,
                encrypt_func,
                key,
                encrypted_bytes=encrypted_bytes,
                overwrite=overwrite
            ): file_info[0] for file_info in file_tasks
        }
        
        # Process completed tasks as they finish
        for future in as_completed(future_to_file):
            file_path = future_to_file[future]
            try:
                success, processed_file, result = future.result(timeout=60)
                if success:
                    encrypted_count += 1
                    progress.update(True)
                else:
                    failed_count += 1
                    progress.update(False)
                    print(f"\nFailed to encrypt {processed_file}: {result}")
            except Exception as e:
                failed_count += 1
                progress.update(False)
                print(f"\nException processing {file_path}: {e}")
    
    return key, encrypted_count, failed_count

def threaded_decrypt_folder(folder_path, decrypt_func, key, output_folder_path=None, 
                          encrypted_bytes=None, overwrite=False, max_workers=4):

    folder_path = Path(folder_path)
    if not folder_path.exists() or not folder_path.is_dir():
        print(f"Error: {folder_path} is not a valid directory")
        return 0, 0
    
    # Collect all .neko files first
    file_tasks = []
    for file_path in folder_path.rglob('*.neko'):
        if file_path.is_file():
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
            
            file_tasks.append((file_path, file_output_path))
    
    if not file_tasks:
        print("No .neko files found to decrypt")
        return 0, 0
    
    print(f"Found {len(file_tasks)} .neko files to decrypt using {max_workers} threads")
    
    # Process with thread-safe progress
    progress = ThreadSafeProgress(len(file_tasks))
    decrypted_count = 0
    failed_count = 0
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all tasks
        future_to_file = {
            executor.submit(
                decrypt_file_worker,
                file_info,
                decrypt_func,
                key,
                encrypted_bytes=encrypted_bytes,
                overwrite=overwrite
            ): file_info[0] for file_info in file_tasks
        }
        
        # Process completed tasks as they finish
        for future in as_completed(future_to_file):
            file_path = future_to_file[future]
            try:
                success, processed_file, result = future.result(timeout=60)
                if success:
                    decrypted_count += 1
                    progress.update(True)
                else:
                    failed_count += 1
                    progress.update(False)
                    print(f"\nFailed to decrypt {processed_file}: {result}")
            except Exception as e:
                failed_count += 1
                progress.update(False)
                print(f"\nException processing {file_path}: {e}")
    
    return decrypted_count, failed_count

def get_optimal_thread_count():
    cpu_count = os.cpu_count()
    # Use fewer threads to avoid blocking
    optimal_threads = max(2, min(4, int(cpu_count * 0.50)))
    return optimal_threads