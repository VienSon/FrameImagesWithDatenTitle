#!/usr/bin/env python3
from __future__ import annotations

import queue
import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from frame_auto_date_title import process_folder, read_exif_date, read_title

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".tif", ".tiff", ".png"}


class FrameApp:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("Frame Auto Date + Title")
        self.root.geometry("760x520")

        self.messages: queue.Queue[tuple[str, object]] = queue.Queue()
        self.worker_thread: threading.Thread | None = None
        self.scan_thread: threading.Thread | None = None

        self.input_var = tk.StringVar(value=str(Path.cwd() / "photo"))
        self.output_var = tk.StringVar(value=str(Path.cwd() / "framed"))
        self.border_var = tk.StringVar(value="80")
        self.bottom_var = tk.StringVar(value="240")
        self.pad_var = tk.StringVar(value="40")
        self.date_font_var = tk.StringVar(value="60")
        self.title_font_var = tk.StringVar(value="80")
        self.progress_var = tk.DoubleVar(value=0.0)
        self.status_var = tk.StringVar(value="Ready")
        self.image_count_var = tk.StringVar(value="Images: 0")

        self._build_ui()
        self.root.after(100, self._poll_messages)
        self._start_metadata_scan()

    def _build_ui(self) -> None:
        main = ttk.Frame(self.root, padding=14)
        main.pack(fill=tk.BOTH, expand=True)

        ttk.Label(main, text="Input Folder").grid(row=0, column=0, sticky="w")
        ttk.Entry(main, textvariable=self.input_var).grid(row=0, column=1, sticky="ew", padx=8)
        ttk.Button(main, text="Browse", command=self._browse_input).grid(row=0, column=2, sticky="ew")
        self.scan_button = ttk.Button(main, text="Load List", command=self._start_metadata_scan)
        self.scan_button.grid(row=0, column=3, sticky="ew", padx=(8, 0))

        ttk.Label(main, text="Output Folder").grid(row=1, column=0, sticky="w", pady=(8, 0))
        ttk.Entry(main, textvariable=self.output_var).grid(row=1, column=1, sticky="ew", padx=8, pady=(8, 0))
        ttk.Button(main, text="Browse", command=self._browse_output).grid(row=1, column=2, sticky="ew", pady=(8, 0))

        params = ttk.LabelFrame(main, text="Settings", padding=10)
        params.grid(row=2, column=0, columnspan=4, sticky="ew", pady=(12, 0))

        self._add_labeled_entry(params, "Border (px)", self.border_var, 0, 0)
        self._add_labeled_entry(params, "Bottom Extra (px)", self.bottom_var, 0, 2)
        self._add_labeled_entry(params, "Text Padding (px)", self.pad_var, 1, 0)
        self._add_labeled_entry(params, "Date Font Size", self.date_font_var, 1, 2)
        self._add_labeled_entry(params, "Title Font Size", self.title_font_var, 2, 0)

        actions = ttk.Frame(main)
        actions.grid(row=3, column=0, columnspan=4, sticky="ew", pady=(12, 0))
        self.run_button = ttk.Button(actions, text="Run", command=self._run)
        self.run_button.pack(side=tk.LEFT)

        self.progress = ttk.Progressbar(
            actions,
            variable=self.progress_var,
            maximum=100,
            mode="determinate",
            length=300,
        )
        self.progress.pack(side=tk.LEFT, padx=12)
        ttk.Label(actions, textvariable=self.status_var).pack(side=tk.LEFT)

        meta_header = ttk.Frame(main)
        meta_header.grid(row=4, column=0, columnspan=4, sticky="ew", pady=(12, 0))
        ttk.Label(meta_header, text="Input Images").pack(side=tk.LEFT)
        ttk.Label(meta_header, textvariable=self.image_count_var).pack(side=tk.LEFT, padx=(12, 0))

        self.meta_table = ttk.Treeview(
            main,
            columns=("filename", "capture_date", "title"),
            show="headings",
            height=9,
        )
        self.meta_table.heading("filename", text="Filename")
        self.meta_table.heading("capture_date", text="Capture Date")
        self.meta_table.heading("title", text="Title")
        self.meta_table.column("filename", width=260, anchor="w")
        self.meta_table.column("capture_date", width=120, anchor="w")
        self.meta_table.column("title", width=420, anchor="w")
        self.meta_table.grid(row=5, column=0, columnspan=4, sticky="nsew")

        meta_scroll = ttk.Scrollbar(main, orient="vertical", command=self.meta_table.yview)
        self.meta_table.configure(yscrollcommand=meta_scroll.set)
        meta_scroll.grid(row=5, column=4, sticky="ns")

        ttk.Label(main, text="Log").grid(row=6, column=0, columnspan=4, sticky="w", pady=(12, 0))
        self.log = tk.Text(main, wrap="word", height=12, state="disabled")
        self.log.grid(row=7, column=0, columnspan=4, sticky="nsew")

        scroll = ttk.Scrollbar(main, orient="vertical", command=self.log.yview)
        self.log.configure(yscrollcommand=scroll.set)
        scroll.grid(row=7, column=4, sticky="ns")

        main.columnconfigure(1, weight=1)
        main.columnconfigure(3, weight=0)
        main.rowconfigure(5, weight=2)
        main.rowconfigure(7, weight=1)
        params.columnconfigure(1, weight=1)
        params.columnconfigure(3, weight=1)

    def _add_labeled_entry(
        self,
        parent: ttk.LabelFrame,
        label: str,
        variable: tk.StringVar,
        row: int,
        col: int,
    ) -> None:
        ttk.Label(parent, text=label).grid(row=row, column=col, sticky="w", padx=(0, 8), pady=4)
        ttk.Entry(parent, textvariable=variable, width=10).grid(row=row, column=col + 1, sticky="ew", pady=4)

    def _browse_input(self) -> None:
        path = filedialog.askdirectory(initialdir=self.input_var.get() or str(Path.cwd()))
        if path:
            self.input_var.set(path)
            self._start_metadata_scan()

    def _browse_output(self) -> None:
        path = filedialog.askdirectory(initialdir=self.output_var.get() or str(Path.cwd()))
        if path:
            self.output_var.set(path)

    def _int_from_var(self, var: tk.StringVar, field_name: str) -> int:
        try:
            value = int(var.get().strip())
        except ValueError as exc:
            raise ValueError(f"{field_name} must be an integer.") from exc
        if value < 0:
            raise ValueError(f"{field_name} must be >= 0.")
        return value

    def _run(self) -> None:
        if self.worker_thread and self.worker_thread.is_alive():
            return

        input_dir = Path(self.input_var.get().strip())
        output_dir = Path(self.output_var.get().strip())

        if not input_dir.exists() or not input_dir.is_dir():
            messagebox.showerror("Invalid Input", f"Input folder not found:\n{input_dir}")
            return

        try:
            border = self._int_from_var(self.border_var, "Border")
            bottom = self._int_from_var(self.bottom_var, "Bottom Extra")
            pad = self._int_from_var(self.pad_var, "Text Padding")
            date_font = self._int_from_var(self.date_font_var, "Date Font Size")
            title_font = self._int_from_var(self.title_font_var, "Title Font Size")
        except ValueError as e:
            messagebox.showerror("Invalid Settings", str(e))
            return

        self._append_log(f"Input: {input_dir}")
        self._append_log(f"Output: {output_dir}")
        self.status_var.set("Running...")
        self.progress_var.set(0)
        self.run_button.configure(state="disabled")
        self.scan_button.configure(state="disabled")

        self.worker_thread = threading.Thread(
            target=self._worker,
            args=(input_dir, output_dir, border, bottom, pad, date_font, title_font),
            daemon=True,
        )
        self.worker_thread.start()

    def _worker(
        self,
        input_dir: Path,
        output_dir: Path,
        border: int,
        bottom: int,
        pad: int,
        date_font: int,
        title_font: int,
    ) -> None:
        def progress_cb(done: int, total: int, _: Path | None) -> None:
            self.messages.put(("progress", (done, total)))

        def log_cb(msg: str) -> None:
            self.messages.put(("log", msg))

        try:
            success, total = process_folder(
                in_dir=input_dir,
                out_dir=output_dir,
                border_px=border,
                bottom_extra_px=bottom,
                pad_px=pad,
                font_size_date=date_font,
                font_size_title=title_font,
                progress_cb=progress_cb,
                log_cb=log_cb,
            )
            self.messages.put(("done", (success, total)))
        except Exception as e:
            self.messages.put(("error", str(e)))

    def _clear_metadata_table(self) -> None:
        for item in self.meta_table.get_children():
            self.meta_table.delete(item)

    def _start_metadata_scan(self) -> None:
        if self.scan_thread and self.scan_thread.is_alive():
            return

        input_dir = Path(self.input_var.get().strip())
        if not input_dir.exists() or not input_dir.is_dir():
            self._clear_metadata_table()
            self.image_count_var.set("Images: 0")
            self.status_var.set("Invalid input folder")
            return

        self._clear_metadata_table()
        self.image_count_var.set("Images: 0")
        self.status_var.set("Reading metadata...")
        self.scan_button.configure(state="disabled")

        self.scan_thread = threading.Thread(target=self._scan_worker, args=(input_dir,), daemon=True)
        self.scan_thread.start()

    def _scan_worker(self, input_dir: Path) -> None:
        try:
            files = [p for p in sorted(input_dir.iterdir()) if p.suffix.lower() in IMAGE_EXTENSIONS]
            total = len(files)
            self.messages.put(("meta_total", total))
            for idx, p in enumerate(files, start=1):
                date_str = read_exif_date(p) or ""
                title = read_title(p) or ""
                self.messages.put(("meta_row", (p.name, date_str, title)))
                self.messages.put(("meta_progress", (idx, total)))
            self.messages.put(("meta_done", total))
        except Exception as e:
            self.messages.put(("meta_error", str(e)))

    def _poll_messages(self) -> None:
        while True:
            try:
                msg_type, payload = self.messages.get_nowait()
            except queue.Empty:
                break

            if msg_type == "log":
                self._append_log(str(payload))
            elif msg_type == "progress":
                done, total = payload  # type: ignore[misc]
                if total <= 0:
                    self.progress_var.set(0)
                    self.status_var.set("No files found")
                else:
                    pct = done * 100.0 / total
                    self.progress_var.set(pct)
                    self.status_var.set(f"Processing {done}/{total}")
            elif msg_type == "done":
                success, total = payload  # type: ignore[misc]
                failed = total - success
                self.status_var.set(f"Done: {success} ok, {failed} failed")
                self.progress_var.set(100 if total > 0 else 0)
                self.run_button.configure(state="normal")
                self.scan_button.configure(state="normal")
                messagebox.showinfo("Completed", f"Processed {total} file(s)\nSucceeded: {success}\nFailed: {failed}")
            elif msg_type == "error":
                self.status_var.set("Error")
                self.run_button.configure(state="normal")
                self.scan_button.configure(state="normal")
                messagebox.showerror("Error", str(payload))
            elif msg_type == "meta_total":
                total = int(payload)
                self.image_count_var.set(f"Images: {total}")
                if total == 0:
                    self.status_var.set("No images found in input folder")
            elif msg_type == "meta_row":
                filename, date_str, title = payload  # type: ignore[misc]
                self.meta_table.insert("", "end", values=(filename, date_str or "-", title or "-"))
            elif msg_type == "meta_progress":
                done, total = payload  # type: ignore[misc]
                self.status_var.set(f"Reading metadata {done}/{total}")
            elif msg_type == "meta_done":
                total = int(payload)
                self.status_var.set(f"Metadata loaded: {total} image(s)")
                self.scan_button.configure(state="normal")
            elif msg_type == "meta_error":
                self.status_var.set("Metadata read failed")
                self.scan_button.configure(state="normal")
                self._append_log(f"ERROR: metadata scan failed: {payload}")

        self.root.after(100, self._poll_messages)

    def _append_log(self, text: str) -> None:
        self.log.configure(state="normal")
        self.log.insert("end", text + "\n")
        self.log.see("end")
        self.log.configure(state="disabled")


def main() -> None:
    root = tk.Tk()
    FrameApp(root)
    root.minsize(900, 650)
    root.mainloop()


if __name__ == "__main__":
    main()
