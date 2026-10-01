"""Tests for global/team/models.py and its link to the generator. Run: python3 tests/test_models.py"""
import json, os, pathlib, shutil, subprocess, sys, tempfile, unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "global" / "team"))
import models  # noqa: E402

os.environ["OPENCODE_TEAM_NO_RELOAD"] = "1"  # the tests must never reload the developer's own OpenCode
MODELS_PY = str(ROOT / "global" / "team" / "models.py")


def run(*args):
    return subprocess.run([sys.executable, MODELS_PY, *args], capture_output=True, text=True)


class ModelsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.v1, self.v2 = self.tmp / "v1", self.tmp / "v2"
        shutil.copytree(ROOT / "global", self.v1)
        shutil.copytree(ROOT / "global", self.v2)
        shutil.copytree(ROOT / "global-v2", self.v2, dirs_exist_ok=True)  # how setup.command installs V2
        self.conf = self.tmp / "models.conf"
        shutil.copy(ROOT / "models.conf", self.conf)

    def test_committed_files_match_models_conf(self):
        conf = models.load_conf(ROOT / "models.conf", local=False)
        for d in (self.v1, self.v2):
            self.assertEqual(models.apply_dir(str(d), conf), [], f"{d.name} is not in sync with models.conf")

    def test_v1_apply(self):
        run("set", "developer", "openai/gpt-5.4-nano", "--conf", str(self.conf), "--dir", str(self.v1))
        cfg = json.loads((self.v1 / "opencode.json").read_text())
        self.assertEqual(cfg["agent"]["developer"], {"model": "openai/gpt-5.4-nano"})  # variant dropped
        self.assertEqual(cfg["agent"]["lead"], {"model": "anthropic/claude-opus-5-5", "variant": "high"})
        self.assertEqual(cfg["agent"]["reporter"]["model"], "google/gemini-3.8-flash")

    def test_v2_apply(self):
        run("set", "lead", "anthropic/claude-sonnet-5-5#high", "--conf", str(self.conf), "--dir", str(self.v2))
        run("set", "background", "openai/gpt-5.4-nano", "--conf", str(self.conf), "--dir", str(self.v2))
        self.assertIn("model: anthropic/claude-sonnet-5-5#high\n", (self.v2 / "agents" / "lead.md").read_text())
        self.assertIn("model: openai/gpt-5.4-nano\n", (self.v2 / "agents" / "reporter.md").read_text())
        cfg = json.loads((self.v2 / "opencode.json").read_text())
        self.assertEqual(cfg["agents"]["explore"]["model"], "openai/gpt-5.4-nano")
        self.assertEqual(cfg["agents"]["build"], {"disabled": True})  # untouched

    def test_apply_is_idempotent(self):
        conf = models.load_conf(self.conf)
        models.apply_dir(str(self.v2), conf)
        self.assertEqual(models.apply_dir(str(self.v2), conf), [])

    def test_bad_input(self):
        self.assertNotEqual(run("set", "nobody", "a/b", "--conf", str(self.conf), "--dir", str(self.v1)).returncode, 0)
        self.assertNotEqual(run("set", "lead", "no-slash", "--conf", str(self.conf), "--dir", str(self.v1)).returncode, 0)
        self.conf.write_text(self.conf.read_text().replace("LEAD=", "LEAD =x ", 1))
        with self.assertRaises(ValueError):
            models.load_conf(self.conf)

    def test_family_warning(self):
        conf = models.load_conf(ROOT / "models.conf")
        self.assertTrue(any("DEVELOPER_STRONG" in w for w in models.warnings(conf)))  # default: Sonnet reviews Sonnet on T2
        conf["REVIEWER"] = "openai/gpt-5.4"
        self.assertEqual(models.warnings(conf), [])

    def test_choice_survives_an_update(self):
        run("set", "developer", "openai/gpt-5.4-nano", "--conf", str(self.conf), "--dir", str(self.v1))
        shutil.copy(ROOT / "models.conf", self.conf)  # what setup.sh does on every run: replace the defaults
        run("apply", "--conf", str(self.conf), "--dir", str(self.v1))
        cfg = json.loads((self.v1 / "opencode.json").read_text())
        self.assertEqual(cfg["agent"]["developer"], {"model": "openai/gpt-5.4-nano"})
        self.assertTrue((self.tmp / "models.local.conf").exists())
        line = [l for l in run("show", "--conf", str(self.conf)).stdout.splitlines() if l.startswith("DEVELOPER ")][0]
        self.assertIn("openai/gpt-5.4-nano", line)
        self.assertIn("*", line)  # marked as your choice

    def test_reset(self):
        run("set", "developer", "openai/gpt-5.4-nano", "--conf", str(self.conf), "--dir", str(self.v1))
        run("set", "lead", "anthropic/claude-sonnet-5-5#max", "--conf", str(self.conf), "--dir", str(self.v1))
        run("reset", "developer", "--conf", str(self.conf), "--dir", str(self.v1))
        cfg = json.loads((self.v1 / "opencode.json").read_text())
        self.assertEqual(cfg["agent"]["developer"], {"model": "google/gemini-3.8-flash", "variant": "high"})
        self.assertEqual(cfg["agent"]["lead"]["variant"], "max")
        run("reset", "--conf", str(self.conf), "--dir", str(self.v1))
        self.assertFalse((self.tmp / "models.local.conf").exists())
        self.assertEqual(json.loads((self.v1 / "opencode.json").read_text())["agent"]["lead"]["variant"], "high")

    def test_preset(self):
        r = run("preset", "claude-only", "--conf", str(self.conf), "--dir", str(self.v2))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("model: anthropic/claude-haiku-4-5-20251001\n", (self.v2 / "agents" / "developer.md").read_text())
        self.assertNotEqual(run("preset", "nope", "--conf", str(self.conf), "--dir", str(self.v2)).returncode, 0)
        self.assertIn("claude-only", run("preset", "--conf", str(self.conf)).stdout)

    def test_slash_command_output(self):
        base = ["--conf", str(self.conf), "--dir", str(self.v1)]
        shown = run("cmd", *base).stdout
        self.assertIn("/model <preset>", shown)
        self.assertIn("This session only", shown)
        self.assertIn("Applied", run("cmd", "developer", "openai/gpt-5.4-nano", *base).stdout)
        self.assertIn("model: google/gemini-3.8-flash", (self.v1 / "commands" / "model.md").read_text())
        self.assertEqual(json.loads((self.v1 / "opencode.json").read_text())["agent"]["developer"]["model"], "openai/gpt-5.4-nano")
        bad = run("cmd", "nobody", "a/b", *base)
        self.assertNotEqual(bad.returncode, 0)
        self.assertIn("Not changed", bad.stdout)
        self.assertIn("Applied", run("cmd", "developer openai/gpt-5.4-mini", *base).stdout)  # one argument holding both words
        self.assertEqual(json.loads((self.v1 / "opencode.json").read_text())["agent"]["developer"]["model"], "openai/gpt-5.4-mini")
        self.assertEqual(run("cmd", "$1", "$2", *base).returncode, 0)  # unexpanded placeholders mean "no arguments"
        self.assertIn("Applied", run("cmd", "reset", *base).stdout)

    def test_command_model_follows_background(self):
        run("set", "background", "openai/gpt-5.4-nano", "--conf", str(self.conf), "--dir", str(self.v1))
        run("set", "background", "openai/gpt-5.4-nano#low", "--conf", str(self.conf), "--dir", str(self.v2))
        self.assertIn("model: openai/gpt-5.4-nano\n", (self.v1 / "commands" / "model.md").read_text())
        self.assertIn("model: openai/gpt-5.4-nano#low\n", (self.v2 / "commands" / "model.md").read_text())

    def test_default_config_dir_follows_xdg(self):
        old = os.environ.get("XDG_CONFIG_HOME")
        os.environ["XDG_CONFIG_HOME"] = "/x/cfg"
        try:
            self.assertEqual(models.config_dir(), "/x/cfg/opencode")
        finally:
            if old is None:
                del os.environ["XDG_CONFIG_HOME"]
            else:
                os.environ["XDG_CONFIG_HOME"] = old


if __name__ == "__main__":
    unittest.main()
