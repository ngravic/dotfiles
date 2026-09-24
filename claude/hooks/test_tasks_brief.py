"""Pruebas de tasks-brief.py. Correr con:

python3 -m unittest discover -s claude/hooks -p 'test_*.py'
"""

import importlib.util
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("tasks_brief", Path(__file__).with_name("tasks-brief.py"))
tb = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(tb)

TASK_LISTS = """Found 3 task list(s):
- Mis tareas | id:GEN | updated:2026-09-16T19:22:05.899Z
- fix-connector | id:FIX | updated:2026-09-24T15:56:01.529Z
- observatory | id:OBS | updated:2026-09-16T19:24:23.300Z"""

TREE = """Task tree (4 tasks):
[ ] Expandir SubscribeMdAck | id:t1
[ ] ▶ Homologación tcr (due: 2026-09-30T00:00:00.000Z) | id:t2
  [ ] Pedir credenciales | id:t3
[x] Revisar aporte de capital (due: 2026-09-18T00:00:00.000Z) | id:t4"""

LIST_OUTPUT = """Found 2 tasks:
Expandir SubscribeMdAck
 (Due: Not set) - Notes: Hoy el ACK trae snapshot.
Struct en control.hpp:66 - ID: t1 - Status: needsAction - URI: https://www.googleapis.com/tasks/v1/lists/FIX/tasks/t1 - Hidden: undefined - Kind: tasks#task}
▶ Homologación tcr
 (Due: 2026-09-30T00:00:00.000Z) - Notes: undefined - ID: t2 - Status: needsAction - URI: https://www.googleapis.com/tasks/v1/lists/FIX/tasks/t2 - Hidden: undefined - Kind: tasks#task}"""


def task(task_id, list_title, state=tb.TODO, title=None, due="", notes=""):
    return tb.Task(task_id, list_title, title or f"tarea {task_id}", state, due, notes)


class ProjectNameTest(unittest.TestCase):
    def test_repo_comun_usa_la_carpeta_del_repo(self):
        self.assertEqual(tb.project_from_common_dir(Path("/home/u/.dotfiles/.git")), ".dotfiles")

    def test_worktree_de_repo_con_bare_usa_la_carpeta_que_contiene_bare(self):
        self.assertEqual(tb.project_from_common_dir(Path("/home/u/Tachyon/fix-connector/.bare")), "fix-connector")

    def test_repo_bare_con_sufijo_git_saca_el_sufijo(self):
        self.assertEqual(tb.project_from_common_dir(Path("/srv/observatory.git")), "observatory")

    def test_fuera_de_git_usa_el_working_dir(self):
        self.assertEqual(tb.project_name("/"), "/")


class ParseTest(unittest.TestCase):
    def test_lee_las_listas_con_su_id(self):
        self.assertEqual(
            tb.parse_task_lists(TASK_LISTS),
            [("GEN", "Mis tareas"), ("FIX", "fix-connector"), ("OBS", "observatory")],
        )

    def test_busca_la_lista_por_nombre_exacto(self):
        lists = tb.parse_task_lists(TASK_LISTS)
        self.assertEqual(tb.find_list(lists, "fix-connector"), "FIX")
        self.assertIsNone(tb.find_list(lists, "Fix-connector"))

    def test_lee_las_notas_por_id_y_descarta_undefined(self):
        notes = tb.parse_notes(LIST_OUTPUT)
        self.assertEqual(notes["t1"], "Hoy el ACK trae snapshot.\nStruct en control.hpp:66")
        self.assertNotIn("t2", notes)

    def test_el_arbol_da_estado_vencimiento_y_notas(self):
        tasks = tb.parse_tree("fix-connector", TREE, tb.parse_notes(LIST_OUTPUT))
        self.assertEqual([t.id for t in tasks], ["t1", "t2", "t3", "t4"])
        self.assertEqual(tasks[0].state, tb.TODO)
        self.assertEqual(tasks[0].notes, "Hoy el ACK trae snapshot.\nStruct en control.hpp:66")
        self.assertEqual(tasks[1].state, tb.IN_PROGRESS)
        self.assertEqual(tasks[1].title, "Homologación tcr")
        self.assertEqual(tasks[1].due, "2026-09-30")
        self.assertEqual(tasks[2].title, "Pedir credenciales")
        self.assertEqual(tasks[3].state, tb.DONE)
        self.assertTrue(all(t.list_title == "fix-connector" for t in tasks))


class BriefTest(unittest.TestCase):
    TASKS = [
        task("a", "fix-connector"),
        task("b", "fix-connector", tb.IN_PROGRESS),
        task("c", "fix-connector", tb.DONE),
        task("d", "observatory"),
        task("e", "Mis tareas"),
        task("f", "Mis tareas", tb.IN_PROGRESS),
        task("g", "Pensar"),
    ]

    def groups(self, project):
        return tb.brief_groups(self.TASKS, project)

    def test_separa_en_curso_por_hacer_y_globales(self):
        in_progress, todo, general = self.groups("fix-connector")
        self.assertEqual([t.id for t in in_progress], ["b"])
        self.assertEqual([t.id for t in todo], ["a"])
        self.assertEqual([t.id for t in general], ["f", "e"])

    def test_globales_no_trae_otros_proyectos_ni_otras_listas(self):
        _, _, general = self.groups("fix-connector")
        self.assertFalse({"d", "g"} & {t.id for t in general})

    def test_render_con_lista_del_proyecto(self):
        text = tb.render_brief("fix-connector", True, self.groups("fix-connector"), {"a": "Tarea A — sin fecha"})
        self.assertEqual(
            text.splitlines(),
            [
                "Tareas — fix-connector",
                "En curso",
                "- tarea b",
                "Por hacer",
                "- Tarea A — sin fecha",
                "Globales",
                "- ▶ tarea f",
                "- tarea e",
            ],
        )

    def test_render_sin_lista_del_proyecto(self):
        text = tb.render_brief(".dotfiles", False, self.groups(".dotfiles"), {})
        self.assertIn("- (no hay lista .dotfiles en Google Tasks)", text.splitlines())

    def test_render_con_secciones_vacias(self):
        text = tb.render_brief("api", True, ([], [], []), {})
        self.assertEqual(text.splitlines(), ["Tareas — api", "- (nada)", "Globales", "- (nada)"])

    def test_render_corta_las_secciones_largas(self):
        many = [task(str(i), "api") for i in range(tb.MAX_LINES + 3)]
        lines = tb.render_brief("api", True, ([], many, []), {}).splitlines()
        self.assertIn("- (+3 más)", lines)
        self.assertEqual(len([line for line in lines if line.startswith("- tarea")]), tb.MAX_LINES)

    def test_linea_por_defecto_marca_las_vencidas(self):
        self.assertEqual(tb.default_line(task("x", "api", due="2026-09-30"), "2026-09-24"), "tarea x — vence 2026-09-30")
        self.assertEqual(tb.default_line(task("x", "api", due="2026-09-20"), "2026-09-24"), "tarea x — Vencida 2026-09-20")


class SummaryTest(unittest.TestCase):
    def test_lee_el_json_del_resumen_aunque_venga_con_texto_alrededor(self):
        tasks = [task("a", "api"), task("b", "api")]
        reply = 'Acá va:\n```json\n{"1": "A — sin fecha", "2": "B — bloqueada"}\n```'
        self.assertEqual(tb.parse_summary(reply, tasks), {"a": "A — sin fecha", "b": "B — bloqueada"})

    def test_resumen_invalido_no_devuelve_lineas(self):
        self.assertEqual(tb.parse_summary("no sé", [task("a", "api")]), {})


class RawListingTest(unittest.TestCase):
    def test_muestra_todas_las_listas_con_estado_y_notas(self):
        tasks = [
            task("a", "fix-connector", notes="Nota\nlarga"),
            task("b", "fix-connector", tb.DONE),
            task("c", "Mis tareas", tb.IN_PROGRESS, due="2026-09-30"),
        ]
        lists = [("GEN", "Mis tareas"), ("FIX", "fix-connector"), ("OBS", "observatory")]
        text = tb.raw_listing(tasks, lists, "fix-connector")
        self.assertIn("## fix-connector", text)
        self.assertIn("- [Por hacer] tarea a", text)
        self.assertIn("  Notas: Nota larga", text)
        self.assertIn("- [Hecha] tarea b", text)
        self.assertIn("## Mis tareas (Globales)", text)
        self.assertIn("- [En curso] tarea c (vence 2026-09-30)", text)
        self.assertIn("## observatory\n- (vacía)", text)


if __name__ == "__main__":
    unittest.main()
