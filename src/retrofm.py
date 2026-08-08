import os
import subprocess
from pathlib import Path

script_dir = os.path.dirname(os.path.abspath(__file__))

fmhandler = os.path.join(script_dir, "PiFmAdv", "src", "pi_fm_adv")

songs = [str(song) for song in Path(script_dir).joinpath("public", "songs").glob("*.wav")]

while songs:
    song = songs.pop(0)
    print(f"Playing: {song}")
    subprocess.run([fmhandler, "--audio", song, "--freq", "103.3", "--preemph", "eu"])