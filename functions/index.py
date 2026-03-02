import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    action = os.environ.get('ACTION')
    
    
    courses_tbl = os.environ.get('COURSES_TABLE_NAME')
    authors_tbl = os.environ.get('AUTHORS_TABLE_NAME')
    
    message = f"Функція [{action}] успішно запущена."

    
    if action == "create-course":
        table = dynamodb.Table(courses_tbl)
        table.put_item(Item={
            'id': 'c-101', 
            'Title': 'Terraform Pro', 
            'Category': 'DevOps'
        })
        message = "Курс створено в таблиці Courses!"
        
    
    elif action == "create-author":
        table = dynamodb.Table(authors_tbl)
        table.put_item(Item={
            'id': 'a-101', 
            'Name': 'John Doe',
            'Expertise': 'Cloud'
        })
        message = "Автора створено в таблиці Authors!"

    return {
        'statusCode': 200,
        'body': json.dumps({
            "message": message,
            "action": action,
            "arns": {
                "courses": os.environ.get('COURSES_TABLE_ARN'),
                "authors": os.environ.get('AUTHORS_TABLE_ARN'),
                "categories": os.environ.get('CATEGORIES_TABLE_ARN')
            }
        }, ensure_ascii=False)
    }