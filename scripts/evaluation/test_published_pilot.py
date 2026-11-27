"""Offline regression checks for benchmark isolation and evidence mapping."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('pilot', Path(__file__).with_name('prepare_published_pilot.py'))
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)


class PreparationTests(unittest.TestCase):
    def test_rhelm_preserves_cutoff_roles_and_keeps_labels_out_of_inputs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            paths = ['conversations/David_R._Ellis/conversation_2024_01_01.json',
                     'conversations/David_R._Ellis/conversation_2024_01_02.json',
                     'emails/David_R._Ellis/01_email_2024_01_01.txt',
                     'attachments/David_R._Ellis/01_notes_task_x.md',
                     'QA_final/low_score_qa_David_R._Ellis_all_validated.jsonl']
            (root / 'rhelm-blob-metadata.json').write_text(json.dumps(dict(sha=pilot.RHELM_REV, siblings=[dict(rfilename=p) for p in paths])))
            for p in paths:
                (root / 'rhelm' / p).parent.mkdir(parents=True, exist_ok=True)
            for day, p in zip(['2024-01-01', '2024-01-02'], paths[:2]):
                (root / 'rhelm' / p).write_text(json.dumps(dict(date=day, conversation=[dict(turn=1, timestamp=day+'T10:00:00', user='Fictional user text.', assistant='Fictional response.')])))
            (root / 'rhelm' / paths[2]).write_text('From: person@example.invalid\nFictional email')
            (root / 'rhelm' / paths[3]).write_text('Fictional note')
            qa = dict(id='fact_a', question='What was said?', question_date='2024-01-02', question_type='fact', answer='SECRET_LABEL_ONLY', supporting_evidence=['2024-01-01:1', '01_notes_task_x.md:heading'])
            (root / 'rhelm' / paths[4]).write_text(json.dumps(qa)+'\n')
            siblings = []
            for p in paths:
                raw = (root / 'rhelm' / p).read_bytes()
                siblings.append(dict(rfilename=p, size=len(raw), blobId=pilot.hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()))
            (root / 'rhelm-blob-metadata.json').write_text(json.dumps(dict(sha=pilot.RHELM_REV, siblings=siblings)))
            cases, labels, _ = pilot.prepare_rhelm(root, False)
            self.assertEqual(len(cases[0]['records']), 4)
            self.assertEqual({r['speaker'] for r in cases[0]['records']}, {'user', 'assistant', 'email', 'attachment'})
            self.assertNotIn('SECRET_LABEL_ONLY', json.dumps(cases))
            self.assertNotIn('supporting_evidence', json.dumps(cases))
            self.assertEqual(labels[0]['unmappedEvidence'], [])
            self.assertEqual(len(labels[0]['supportingSourceIDs']), 3)
            self.assertEqual(cases, pilot.prepare_rhelm(root, False)[0])
            (root / 'rhelm' / paths[3]).write_text('Modified data')
            with self.assertRaisesRegex(ValueError, 'identity mismatch'):
                pilot.prepare_rhelm(root, False)

    def test_same_source_in_different_personas_has_distinct_ids(self):
        def row(persona):
            return pilot.record('test', persona, 'session:0', 'session', '2024-01-01', 'user', 'Some text')
        self.assertNotEqual(row('one')['id'], row('two')['id'])
        self.assertEqual(row('one'), row('one'))

    def test_oversize_and_empty_sources_fail_instead_of_truncating(self):
        for text in ['', 'a' * 101001, 'ع' * 50501]:
            with self.assertRaises(ValueError):
                pilot.record('test', 'persona', 'source', 'session', '2024-01-01', 'user', text)

    def test_repeated_upstream_sessions_preserve_occurrences_dates_and_labels(self):
        q = dict(question_id='fixture', haystack_session_ids=['repeated', 'answer-session', 'repeated'],
                 haystack_dates=['2024/01/01 (Mon) 10:00', '2024/01/02 (Tue) 10:00', '2024/01/03 (Wed) 10:00'],
                 haystack_sessions=[[dict(role='user', content='Same original message')],
                                    [dict(role='user', content='Labelled evidence', has_answer=True)],
                                    [dict(role='user', content='Same original message')]])
        records, evidence = pilot.longmem_records(q)
        self.assertEqual(len(records), 3)
        self.assertEqual(len({r['id'] for r in records}), 3)
        self.assertEqual([r['sourceID'] for r in records], ['repeated:0', 'answer-session:0', 'repeated:0'])
        self.assertEqual([r['date'] for r in records], q['haystack_dates'])
        self.assertEqual(evidence, ['answer-session:0'])
        self.assertEqual([records[i]['sourceOccurrence'] for i in [0, 2]], [0, 1])
        self.assertEqual(records, pilot.longmem_records(q)[0])
        pilot.validate_cases([dict(id='fixture', records=records)])
        invalid = [dict(r) for r in records]
        invalid[2]['sourceOccurrence'] = 0
        with self.assertRaisesRegex(ValueError, 'Unqualified repeated'):
            pilot.validate_cases([dict(id='fixture', records=invalid)])

    def test_combined_order_preserves_original_case_and_label_objects(self):
        rc = [dict(id=f'r{i}') for i in range(7)]
        lc = [dict(id=f'l{i}') for i in range(7)]
        rl = [dict(caseID=f'r{i}') for i in range(7)]
        ll = [dict(caseID=f'l{i}') for i in range(7)]
        cases, labels, _ = pilot.combine((rc, rl, []), (lc, ll, []))
        self.assertEqual([c['id'] for c in cases], [x for i in range(7) for x in [f'r{i}', f'l{i}']])
        self.assertIs(cases[0], rc[0])
        self.assertIs(labels[1], ll[0])
        with self.assertRaises(ValueError):
            pilot.combine((rc[:6], rl[:6], []), (lc, ll, []))

    def test_revision_mismatch_fails_before_using_assets(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'rhelm-blob-metadata.json').write_text(json.dumps(dict(sha='wrong', siblings=[])))
            with self.assertRaisesRegex(ValueError, 'revision mismatch'):
                pilot.prepare_rhelm(root, False)


class ScoringTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('scorer', Path(__file__).with_name('score_published_pilot.py'))
        self.scorer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.scorer)

    def test_rhelm_turn_label_accepts_either_speaker_without_double_denominator(self):
        expected = {self.scorer.group_source('rhelm', s) for s in ['2024-01-01:1:user', '2024-01-01:1:assistant']}
        found = {self.scorer.group_source('rhelm', '2024-01-01:1:assistant')}
        self.assertEqual(self.scorer.metrics(expected, found)['recall'], 1)
        self.assertEqual(self.scorer.metrics(expected, found)['expected'], 1)

    def test_native_input_hash_and_protocol_identity_must_match(self):
        raw = json.dumps(dict(protocolID='frozen-test', cases=[])).encode()
        labels = dict(protocolID='frozen-test', labels=[])
        native = dict(protocolID='frozen-test', inputSHA256=pilot.hashlib.sha256(raw).hexdigest(), results=[])
        self.assertEqual(self.scorer.validate_run_identity(raw, labels, native)['cases'], [])
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            self.scorer.validate_run_identity(raw + b' ', labels, native)
        with self.assertRaisesRegex(ValueError, 'protocols differ'):
            self.scorer.validate_run_identity(raw, dict(protocolID='different'), native)

    def test_empty_labels_do_not_automatically_pass_abstention(self):
        self.assertIsNone(self.scorer.metrics(set(), set())['recall'])

    def test_missing_case_keeps_denominator_and_cross_case_source_is_rejected(self):
        inputs = dict(protocolID='test', cases=[dict(id='one', category='fact', benchmark='rhelm', records=[dict(id='uuid1', sourceID='one-source', sessionID='session')]), dict(id='two', category='fact', benchmark='rhelm', records=[])])
        labels = dict(labels=[dict(caseID='one', supportingSourceIDs=['one-source']), dict(caseID='two', supportingSourceIDs=[])])
        outputs = dict(results=[dict(caseID='one', status='completed', retrievedSourceIDs=['one-source'], candidateSourceIDs=['one-source'], rankingCompleted=True, retrievalCompleted=True)])
        result = self.scorer.score(inputs, labels, outputs)
        self.assertEqual(result['denominator'], 2)
        self.assertEqual(result['benchmarkSummaries']['rhelm']['denominator'], 2)
        self.assertEqual(result['rows'][1]['status'], 'not-run')
        self.assertEqual(result['rows'][0]['candidateRetrieval']['recall'], 1)
        outputs['results'].append(dict(caseID='two', status='budget-not-run', retrievedSourceIDs=[]))
        budget_result = self.scorer.score(inputs, labels, outputs)
        self.assertIsNone(budget_result['rows'][1]['retrieval'])
        outputs['results'][0].update(status='runtime-error', retrievalCompleted=False, retrievedSourceIDs=[])
        self.assertIsNone(self.scorer.score(inputs, labels, outputs)['rows'][0]['retrieval'])
        outputs['results'][0].update(status='budget-timeout', rankingCompleted=True, retrievalCompleted=False)
        timed = self.scorer.score(inputs, labels, outputs)
        self.assertIsNone(timed['rows'][0]['retrieval'])
        self.assertEqual(timed['rows'][0]['candidateRetrieval']['recall'], 1)
        self.assertFalse(timed['rows'][0]['caseScoreEligible'])
        self.assertEqual(timed['rows'][0]['answerReview'], 'not-scoreable-incomplete-run')
        self.assertEqual(timed['statusCounts'], {'budget-timeout': 1, 'budget-not-run': 1})
        outputs['results'][0]['retrievedSourceIDs'] = ['other-persona-source']
        with self.assertRaises(ValueError):
            self.scorer.score(inputs, labels, outputs)


if __name__ == '__main__':
    unittest.main()
