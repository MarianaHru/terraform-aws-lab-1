import urllib3
import json
import os

http = urllib3.PoolManager()

def lambda_handler(event, context):
    url = os.environ.get('SLACK_WEBHOOK_URL')
    
    # Витягуємо повідомлення з SNS
    sns_message = event['Records'][0]['Sns']['Message']
    subject = event['Records'][0]['Sns'].get('Subject', 'AWS Alert')
    
    msg = {
        "text": f"🚨 *{subject}*\n```{sns_message}```"
    }
    
    encoded_msg = json.dumps(msg).encode('utf-8')
    resp = http.request('POST', url, body=encoded_msg, headers={'Content-Type': 'application/json'})
    
    return {"status": resp.status}
