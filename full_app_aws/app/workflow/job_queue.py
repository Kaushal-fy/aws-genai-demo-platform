import json
import os


class JobQueue:

    def __init__(self, file_path="queue.json"):
        self.file_path = file_path

        if not os.path.exists(self.file_path):
            with open(self.file_path, "w") as f:
                json.dump([], f)

    def _read(self):
        with open(self.file_path, "r") as f:
            return json.load(f)

    def _write(self, data):
        with open(self.file_path, "w") as f:
            json.dump(data, f, indent=2)

    def push(self, job_id: str):

        queue = self._read()
        queue.append(job_id)
        self._write(queue)

    def pop(self):

        queue = self._read()

        if not queue:
            return None

        job_id = queue.pop(0)
        self._write(queue)

        return job_id
