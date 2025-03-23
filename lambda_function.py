import urllib3
import json
import boto3
from datetime import datetime, timedelta
import os
import re


print("Prod Version - Stable")
sns_arn = os.getenv("sns_arn")
#import logging

# Set up logging
#logger = logging.getLogger()
#logger.setLevel(logging.INFO)

# Create an HTTP client
http = urllib3.PoolManager()

# Initialize the DynamoDB client
dynamodb = boto3.resource("dynamodb")
table_name = "price_dollar"  # Name of the DynamoDB table
table = dynamodb.Table(table_name)

utc_now = datetime.utcnow()
utc_minus_5 = utc_now - timedelta(hours=5)

def check_if_item_exists_in_dynamodb():
    try:
        response = table.scan()
        items = response["Items"]
        print("Successfully read data from DynamoDB")
        print("items:", items)
        if len(items) > 0:
            return True
        else:
            return False
    except Exception as e:
        print(f"Failed to read data from DynamoDB: {e}")
        return False

def read_price_from_dynamodb():
    # Read from DynamoDB

    try:
        response = table.scan()
        items = response["Items"]
        print("Successfully read data from DynamoDB")
        print("items:", items)
        return items[0]["price"]
    except Exception as e:
        print(f"Failed to read data from DynamoDB: {e}")
        return None

def update_price_to_dynamodb(usd):
    new_price=usd
    try:

        response = table.update_item(
            Key={"id": "1"},
            UpdateExpression="SET #ts = :new_price",
            ExpressionAttributeNames={"#ts": "price"},
            ExpressionAttributeValues={":new_price": new_price},
            ReturnValues="UPDATED_NEW"
        )
        print(f"Updated item: {response['Attributes']}")
    except Exception as e:
        print(f"Failed to update item: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Failed to update item', 'error': str(e)})
        }

def get_price():
    try:
        #url = "https://script.google.com/macros/s/AKfycbxoDsLKnhaaQ8kcFz7DApoi7E9VEIZEHcqeMZRAVRPGxi1YNdcI0izmHdzxOIGgbbM/exec"
        url = os.getenv("url")

        # Make the GET request
        #response = http.request('GET', url)
        #response = http.request('GET', url, timeout=8.0)
        response = http.request('GET', url, timeout=8.0, redirect=True)


        print("response: ", response)
        # Parse the response body (if it's JSON)
        print("Raw response body:", response.data.decode('utf-8'))
        data = json.loads(response.data.decode('utf-8'))
        print("Response content: ", data)
        # Access the value you're interested in
        usd = data[0]["USD"]["venta"]
        
        # Print the result
        print(f"Price USD: {usd}")

        #print("usd: ", usd)

        return usd
    except Exception as e:
        print(f"Failed to get price: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Failed to get price', 'error': str(e)})
        }

def publish_to_sns(previous_price,current_price,result_TRM):
    client = boto3.client("sns")
    if result_TRM != "failure":
        resp = client.publish(TargetArn=sns_arn, Message=f'Current Price USD: {current_price} COP \nPrevious Price USD: {previous_price} COP \nTRM: {result_TRM} COP\n https://cashxchange.com.co/', Subject="Lambda Dollar price")
    else:
        resp = client.publish(TargetArn=sns_arn, Message=f'Current Price USD: {current_price} COP \nPrevious Price USD: {previous_price} COP \n https://cashxchange.com.co/', Subject="Lambda Dollar price")


    resp = client.publish(TargetArn=sns_arn, Message=f'Current Price USD: {current_price} COP \nPrevious Price USD: {previous_price} COP \n https://cashxchange.com.co/', Subject="Lambda Dollar price")
    print("Published to SNS. Resp: ", resp)

def get_TRM():
    http = urllib3.PoolManager()

    # Target URL
    url = "https://www.dolar-colombia.com/"

    try:
        # Fetch the HTML content
        response = http.request("GET", url)

        if response.status == 200:
            # Decode the response data
            html_content = response.data.decode("utf-8")

            # Regex pattern to extract the desired information (USD to COP rate)
            pattern = r"USD \$ 1 = COP \$ ([\d,]+\.\d+)"
            #match = re.search(pattern, html_content, re.IGNORECASE)
            match = re.search(pattern, html_content)
            if match:
                
                # Extracted rate information
                rate_info = match.group(1)
                print(f"Extracted Rate Info: {rate_info}")
                return rate_info
            else:
                print("USD to COP rate not found in the content.")
                return "failure"
        else:
            print(f"Failed to fetch the URL. HTTP status: {response.status}")
            return "failure"
    except Exception as e:
        print(f"An error occurred: {e}")
        return "failure"

def lambda_handler(event, context):
    current_price=get_price()
    #print("usd:", current_price)
    #current_price=4000

    # read previous price from DB:

    if check_if_item_exists_in_dynamodb():
        print("item exists already!")
        previous_price=read_price_from_dynamodb()
    else:
        print("item doesn't exist!")
        previous_price="0"

    print("previous_price: ", previous_price)

    if int(previous_price) > current_price or int(previous_price) == 0:
        result_TRM=get_TRM()
        publish_to_sns(previous_price,current_price,result_TRM)
        update_price_to_dynamodb(current_price)
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Lambda successfully run',
                'USD Price': str(current_price),
                'Previous Price': str(previous_price),
                'TRM': str(result_TRM)
            })
        }    
    else:
        print("Price is not lower than previous price, not publishing to SNS")
        update_price_to_dynamodb(current_price)
        result_TRM=get_TRM()
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Lambda successfully run',
                'USD Price': str(current_price),
                'Previous Price': str(previous_price),
                'TRM': str(result_TRM),
                'timestamp': utc_minus_5.isoformat() 
            })
        }    
    


# $ aws logs filter-log-events --log-group-name "/aws/lambda/lambda_sns_dollar" --filter-pattern "Price" --profile personal_aws --region="us-east-1" 
# CURL With redirection:
# curl -L -X GET "https://script.googleusercontent.com/macros/echo?user_content_key=qJR-xgs635rwS7Ftvvl8wEzGb8OIGJ3Sbs6Uy_vP2uiRC1g2xsRjxNUB-2AnIg0mpCebwfhkpDxlkOPM05A3ZEODbDjdzvEAm5_BxDlH2jW0nuo2oDemN9CCS2h10ox_1xSncGQajx_ryfhECjZEnJSwpOTIjqSsJ8_ZXKEIF7-wk6J_bhn_O6J2u7mBTc_XQ_VrqpWnnLGJmQnvuRCz6jeqAPIR5beusRhWN4HcwxxFvnZ3JX3SHgE&lib=MXaCsJ0-g_hidvbxEGuOuen2l86n1Hj67"
