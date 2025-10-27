const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, PutCommand, ScanCommand, UpdateCommand, DeleteCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({});
const dynamodb = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.TABLE_NAME;

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    const httpMethod = event.httpMethod;
    const path = event.path;
    
    try {
        let response;
        
        switch (httpMethod) {
            case 'GET':
                if (event.pathParameters && event.pathParameters.id) {
                    // Get specific inventory item
                    response = await getInventoryItem(event.pathParameters.id);
                } else {
                    // List all inventory items
                    response = await listInventory();
                }
                break;
            
            case 'POST':
                // Create new inventory item
                const itemData = JSON.parse(event.body);
                response = await createInventoryItem(itemData);
                break;
            
            case 'PUT':
                // Update inventory item
                const updateData = JSON.parse(event.body);
                response = await updateInventoryItem(event.pathParameters.id, updateData);
                break;
            
            case 'DELETE':
                // Delete inventory item
                response = await deleteInventoryItem(event.pathParameters.id);
                break;
            
            default:
                response = {
                    statusCode: 400,
                    body: JSON.stringify({ message: 'Unsupported method' })
                };
        }
        
        return response;
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Internal server error', error: error.message })
        };
    }
};

async function getInventoryItem(itemId) {
    const params = {
        TableName: TABLE_NAME,
        Key: { item_id: itemId }
    };
    
    const result = await dynamodb.send(new GetCommand(params));
    
    if (!result.Item) {
        return {
            statusCode: 404,
            body: JSON.stringify({ message: 'Inventory item not found' })
        };
    }
    
    return {
        statusCode: 200,
        body: JSON.stringify(result.Item)
    };
}

async function listInventory() {
    const params = {
        TableName: TABLE_NAME
    };
    
    const result = await dynamodb.send(new ScanCommand(params));
    
    return {
        statusCode: 200,
        body: JSON.stringify(result.Items)
    };
}

async function createInventoryItem(itemData) {
    const itemId = `item-${Date.now()}`;
    const timestamp = new Date().toISOString();
    
    const params = {
        TableName: TABLE_NAME,
        Item: {
            item_id: itemId,
            ...itemData,
            created_at: timestamp,
            updated_at: timestamp
        }
    };
    
    await dynamodb.send(new PutCommand(params));
    
    return {
        statusCode: 201,
        body: JSON.stringify({ item_id: itemId, message: 'Inventory item created successfully' })
    };
}

async function updateInventoryItem(itemId, updateData) {
    const timestamp = new Date().toISOString();
    
    const params = {
        TableName: TABLE_NAME,
        Key: { item_id: itemId },
        UpdateExpression: 'SET updated_at = :timestamp',
        ExpressionAttributeValues: {
            ':timestamp': timestamp
        },
        ReturnValues: 'ALL_NEW'
    };
    
    // Add other fields to update
    Object.keys(updateData).forEach((key, index) => {
        params.UpdateExpression += `, ${key} = :val${index}`;
        params.ExpressionAttributeValues[`:val${index}`] = updateData[key];
    });
    
    const result = await dynamodb.send(new UpdateCommand(params));
    
    return {
        statusCode: 200,
        body: JSON.stringify(result.Attributes)
    };
}

async function deleteInventoryItem(itemId) {
    const params = {
        TableName: TABLE_NAME,
        Key: { item_id: itemId }
    };
    
    await dynamodb.send(new DeleteCommand(params));
    
    return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Inventory item deleted successfully' })
    };
}
