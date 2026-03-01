import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    table_name = os.environ.get('TABLE_NAME')
    action = os.environ.get('ACTION')
    table = dynamodb.Table(table_name)
    
    sample_id = "101"
    sample_title = "Cloud Computing with Terraform"
    sample_category = "DevOps"

    if action == "create":
        table.put_item(Item={
            'ID': sample_id,
            'Title': sample_title,
            'Category': sample_category
        })
        message = f"Курс '{sample_title}' створено з ID: {sample_id}"
    else:
        message = f"Функція {action} виконана для таблиці {table_name}"

    return {
        'statusCode': 200,
        'body': json.dumps({
            "message": message,
            "data": {
                "ID": sample_id,
                "Title": sample_title,
                "Category": sample_category
            }
        }, ensure_ascii=False)
    }