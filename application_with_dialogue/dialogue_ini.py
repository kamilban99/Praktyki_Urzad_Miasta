import tkinter as tk
from tkinter import messagebox
import configparser
import os


def show_dialogue_from_ini(ini_file):
    # Check if the ini file exists
    if not os.path.exists(ini_file):
        messagebox.showerror("Error", f"The file '{ini_file}' does not exist.")
        return
    
    # Parse the ini file with UTF-8 encoding
    config = configparser.ConfigParser(allow_no_value=True)
    try:
        with open(ini_file, 'r', encoding='utf-8') as file:
            config.read_file(file)
    except Exception as e:
        messagebox.showerror("Error", f"Error reading INI file: {e}")
        return

    # Get the title from the [Title] section
    title = config.get('Title', 'Title', fallback='Title')

    # Get messages from the [Messages] section
    messages = []
    if 'Messages' in config:
        for key in config['Messages']:
            if key.startswith('message'):
                message = config.get('Messages', key).replace('\\n', '\n')  # Handle multi-line messages
                messages.append(message)
    else:
        messagebox.showerror("Error", "The 'Messages' section is missing from the INI file.")
        return
    
    # Get colors from the [Colors] section
    colors = []
    if 'Colors' in config:
        for i in range(1, len(messages) + 1):
            color_key = f'Color{i}'
            color = config.get('Colors', color_key, fallback='black')
            colors.append(color)
    else:
        colors = ['black'] * len(messages)  # Default colors if 'Colors' section is missing

    # Get width and height from the [Width] and [Height] sections
    # for values equal 0 get default values
    default_width = 640
    default_height = 30 + len(messages) * 120
    width = default_width
    height = default_height
    if 'Width' in config:
        try:
            width = int(config.get('Width', 'Width', fallback=default_width))
            if width == 0:
                width = default_width
        except ValueError:
            width = default_width
    if 'Height' in config:
        try:
            height = int(config.get('Height', 'Height', fallback=default_height))
            if height == 0:
                height = default_height
        except ValueError:
            height = default_height


    # Create the main window
    dialog = tk.Tk()

    dialog.title(title)
    
    # Set the window size
    dialog.geometry(f"{width}x{height}")
    
    # Display the messages
    for message, color in zip(messages, colors):
        label = tk.Label(dialog, text=message, font=("Times New Roman", 24), wraplength=width - 40, fg=color, justify=tk.LEFT)
        label.pack(pady=10, padx=20, anchor=tk.W)

    # Create an OK button to close the dialog
    ok_button = tk.Button(dialog, text="OK", command=dialog.destroy, width=10, height=2, font=("Times New Roman", 14))
    ok_button.pack(pady=10)

    # Center the window on the screen
    dialog.update_idletasks()
    dialog.geometry(f'{width}x{height}+{(dialog.winfo_screenwidth() - width) // 2}+{(dialog.winfo_screenheight() - height) // 2}')

    # Start the Tkinter event loop
    dialog.mainloop()

# Automatically show the dialog when the program starts
ini_file_path = 'dialog.ini'  # Ensure this file is in the same directory as the exe
show_dialogue_from_ini(ini_file_path)