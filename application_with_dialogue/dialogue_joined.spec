# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['dialogue_joined.py'],
    pathex=[],
    binaries=[],
    datas=[('C:/Users/praktyka1/AppData/Local/Programs/Python/Python311/tcl/tcl8.6', './tcl/tcl8.6'), ('C:/Users/praktyka1/AppData/Local/Programs/Python/Python311/tcl/tk8.6', './tcl/tk8.6')],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='dialogue_joined',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
