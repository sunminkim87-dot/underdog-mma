import json
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from fastapi.testclient import TestClient
from server.app import create_app

class ServerTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='underdog-api-test-')
        self.path=Path(self.tmp.name)/'accounts.sqlite3'
        self.client=TestClient(create_app(self.path))
        self.session=self.client.post('/session').json()
        self.headers={'Authorization':'Bearer '+self.session['token']}
        self.request_number=0
    def tearDown(self): self.tmp.cleanup()
    def snapshot(self): return self.client.get('/state',headers=self.headers).json()
    def mutate(self,op,payload=None,revision=None,key=None):
        if op in ('month','fight','schedule'):
            snapshot=self.snapshot()
            pending=(snapshot.get('state') or {}).get('current_athlete',{}).get('pending_event','')
            if pending:
                content=json.loads((Path(__file__).parents[1]/'data/progression_data.json').read_text())
                option=next(c for c in content['events'][pending]['choices'] if c['effects'].get('cost',0)==0)
                self.request_number+=1
                resolved=self.client.post('/action/event',json={'revision':snapshot['revision'],'request_id':'resolve_event_'+str(self.request_number).zfill(8),'event':pending,'choice':option['id']},headers=self.headers)
                self.assertEqual(resolved.status_code,200,resolved.text)
        self.request_number+=1
        body=dict(payload or {},revision=self.snapshot()['revision'] if revision is None else revision,request_id=key or ('request_'+str(self.request_number).zfill(12)))
        return self.client.post('/action/'+op,json=body,headers=self.headers)
    def new(self):
        response=self.mutate('new',{'name':'서버 선수','style':'striker','appearance':0})
        self.assertEqual(response.status_code,200,response.text)
        return response.json()
    def test_guest_auth_and_account_isolation(self):
        self.assertEqual(self.client.get('/state').status_code,401)
        self.assertEqual(self.snapshot()['wallet']['cash'],0)
        self.new()
        second=self.client.post('/session').json()
        response=self.client.get('/state',headers={'Authorization':'Bearer '+second['token']}).json()
        self.assertIsNone(response['state'])
    def test_authority_and_calendar(self):
        self.new()
        self.assertEqual(self.mutate('fight',{'strategy':'balanced'}).status_code,409)
        self.assertEqual(self.mutate('month').status_code,200)
        self.assertEqual(self.mutate('month').status_code,200)
        before=self.snapshot()
        denied=self.mutate('month')
        self.assertEqual(denied.status_code,409)
        self.assertTrue(denied.json()['fight_due'])
        self.assertEqual(self.snapshot(),before)
        self.assertEqual(self.mutate('month',{'cash':999999}).status_code,422)
        self.assertEqual(self.mutate('fight',{'strategy':'balanced','winner':'player'}).status_code,422)
        self.assertEqual(self.mutate('fight',{'strategy':'balanced'}).status_code,200)
        self.assertEqual(self.mutate('month').status_code,200)
    def test_idempotency_and_conflicts(self):
        self.new()
        first=self.mutate('month',revision=1,key='same_request_12345')
        second=self.mutate('month',revision=1,key='same_request_12345')
        self.assertEqual(first.json(),second.json())
        self.assertEqual(self.snapshot()['state']['current_athlete']['months'],1)
        self.assertEqual(self.mutate('month',revision=1).status_code,409)
        self.assertEqual(self.mutate('fight',{'strategy':'balanced'},revision=2,key='same_request_12345').status_code,409)
    def test_parallel_requests_cannot_double_advance(self):
        self.new()
        def advance(i):
            return self.client.post('/action/month',json={'revision':1,'request_id':'parallel_request_'+str(i)},headers=self.headers).status_code
        with ThreadPoolExecutor(max_workers=2) as pool: statuses=list(pool.map(advance,[1,2]))
        self.assertEqual(sorted(statuses),[200,409])
        self.assertEqual(self.snapshot()['state']['current_athlete']['months'],1)
    def test_billing_disabled_fails_closed(self):
        response=self.client.post('/billing/verify',headers=self.headers,json={'product_id':'cash_100','purchase_token':'unverified_token_0123'})
        self.assertEqual(response.status_code,503)
        self.assertEqual(self.snapshot()['wallet']['cash'],0)
        forged=self.client.post('/billing/verify',headers=self.headers,json={'product_id':'cash_100','purchase_token':'unverified_token_0123','verified':True,'cash':100000})
        self.assertEqual(forged.status_code,422)
    def test_verified_provider_boundary_and_duplicate_receipt(self):
        # Test-only verifier. No mock payment endpoint is exposed by the application.
        def verified(product,token,uid):
            return {'account_id':uid,'product_id':product,'purchase_state':'PURCHASED' if token=='unit_test_paid_token' else 'PENDING'}
        client=TestClient(create_app(self.path,verifier=verified))
        receipt={'product_id':'cash_100','purchase_token':'unit_test_paid_token'}
        first=client.post('/billing/verify',headers=self.headers,json=receipt)
        second=client.post('/billing/verify',headers=self.headers,json=receipt)
        self.assertEqual(first.json()['wallet']['cash'],100)
        self.assertEqual(second.json()['wallet']['cash'],100)
        receipt['purchase_token']='unit_test_pending_token'
        self.assertEqual(client.post('/billing/verify',headers=self.headers,json=receipt).status_code,403)
        other=client.post('/session').json()
        receipt['purchase_token']='unit_test_paid_token'
        self.assertEqual(client.post('/billing/verify',headers={'Authorization':'Bearer '+other['token']},json=receipt).status_code,409)
    def test_server_reports_actual_recovery(self):
        self.new()
        response=self.mutate('month')
        self.assertEqual(response.status_code,200,response.text)
        report=response.json()['report']
        self.assertEqual(len(report['timeline']),16)
        for event in report['timeline']:
            self.assertAlmostEqual(event['recovered'],max(0,event['fatigue_before']-event['fatigue_after']),places=5)
        self.assertAlmostEqual(report['timeline'][-1]['fatigue_after'],report['fatigue'])
    def test_upgrade_cannot_be_forged(self):
        self.new()
        response=self.mutate('upgrade',{'facility':'boxing'})
        self.assertEqual(response.status_code,409)
        self.assertEqual(self.snapshot()['state']['account_legacy']['lp'],0)
        self.assertEqual(self.mutate('upgrade',{'facility':'boxing','lp':100}).status_code,422)

    def test_approved_bases_and_canonical_stats(self):
        response=self.mutate('new',{'name':'유도 선수','style':'striker','base':'judo','appearance':0})
        self.assertEqual(response.status_code,200,response.text)
        athlete=response.json()['state']['current_athlete']
        self.assertEqual(athlete['background_base'],'judo')
        self.assertEqual(athlete['style'],'wrestler')
        self.assertEqual(sum(athlete['stats'].values()),184)
        self.assertEqual(athlete['stats']['power'],36)
    def test_real_inventory_and_equipment_without_premium_cash(self):
        self.new()
        before=self.snapshot()['state']['current_athlete']['cash']
        bought=self.mutate('buy',{'item':'training_gloves'})
        self.assertEqual(bought.status_code,200,bought.text)
        athlete=bought.json()['state']['current_athlete']
        self.assertEqual(athlete['cash'],before-16)
        self.assertEqual(athlete['equipment']['gloves'],'training_gloves')
        self.assertEqual(self.snapshot()['wallet']['cash'],0)
        self.assertEqual(self.mutate('buy',{'item':'training_gloves'}).status_code,409)
        self.assertEqual(self.mutate('buy',{'item':'mouthguard','price':0}).status_code,422)
        self.assertEqual(self.mutate('equip',{'item':'mouthguard'}).status_code,409)
    def test_event_choices_are_server_owned(self):
        self.new()
        self.assertEqual(self.mutate('event',{'event':'coach_offer','choice':'accept'}).status_code,409)
        progressed=self.mutate('month')
        self.assertEqual(progressed.status_code,200)
        snapshot=self.snapshot()
        self.assertEqual(snapshot['state']['current_athlete']['pending_event'],'meet_jisoo')
        choice=self.mutate('event',{'event':'meet_jisoo','choice':'hello'})
        self.assertEqual(choice.status_code,200,choice.text)
        relation=choice.json()['state']['current_athlete']['relationships']['jisoo']
        self.assertEqual(relation['affinity'],5)
        self.assertEqual(self.mutate('event',{'event':'meet_jisoo','choice':'hello'}).status_code,409)
        focused=self.mutate('focus',{'npc':'jisoo'})
        self.assertEqual(focused.json()['state']['current_athlete']['relationships']['jisoo']['affinity'],5)
        self.assertEqual(self.mutate('focus',{'npc':'harin'}).status_code,409)
        self.assertEqual(self.mutate('focus',{'npc':'jisoo','affinity':100}).status_code,422)
    def test_consumable_retry_decrements_exactly_once(self):
        self.new()
        self.mutate('month')
        snapshot=self.snapshot()
        self.assertGreater(snapshot['state']['current_athlete']['fatigue'],0)
        before=snapshot['state']['current_athlete']['inventory']['sports_drink']
        first=self.mutate('use_item',{'item':'sports_drink'},revision=snapshot['revision'],key='retry_consumable_001')
        second=self.mutate('use_item',{'item':'sports_drink'},revision=snapshot['revision'],key='retry_consumable_001')
        self.assertEqual(first.status_code,200,first.text)
        self.assertEqual(first.json(),second.json())
        athlete=self.snapshot()['state']['current_athlete']
        self.assertEqual(athlete['inventory']['sports_drink'],before-1)
        self.assertEqual(athlete['consumables_used'],1)
        self.assertEqual(athlete['fatigue'],0)
    def test_jobs_cannot_unlock_from_client_payload(self):
        self.new()
        state=self.snapshot()['state']
        schedule=state['schedule']
        schedule[0]['life']='coach_job'
        self.assertEqual(self.mutate('schedule',{'schedule':schedule}).status_code,409)
        self.assertEqual(self.mutate('schedule',{'schedule':schedule,'unlocks':['coach_job']}).status_code,422)
    def test_purchase_concurrency_charges_only_once(self):
        self.new()
        def purchase(i):
            return self.client.post('/action/buy',json={'revision':1,'request_id':'parallel_purchase_'+str(i),'item':'sports_drink'},headers=self.headers).status_code
        with ThreadPoolExecutor(max_workers=2) as pool:statuses=list(pool.map(purchase,[1,2]))
        self.assertEqual(sorted(statuses),[200,409])
        self.assertEqual(self.snapshot()['state']['current_athlete']['cash'],96)
        self.assertEqual(self.snapshot()['state']['current_athlete']['inventory']['sports_drink'],1)

if __name__=='__main__':unittest.main(verbosity=2)
