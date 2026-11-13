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

if __name__=='__main__':unittest.main(verbosity=2)
