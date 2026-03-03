const AWS = require("aws-sdk");
const dynamodb = new AWS.DynamoDB({ region: process.env.AWS_REGION, apiVersion: "2012-08-10" });

exports.handler = (event, context, callback) => {
  console.log("Input event:", JSON.stringify(event));

  const params = {
    Item: {
      id: { S: event.id || "default-id" }, 
      title: { S: event.title || "" }, 
      watchHref: { S: event.watchHref || "" },
      authorId: { S: event.authorId || "" }, 
      length: { S: event.length || "" }, 
      category: { S: event.category || "" }
    },
    TableName: process.env.TABLE_NAME
  };

  dynamodb.putItem(params, (err, data) => {
    if (err) { 
      console.log("DynamoDB Error:", err); 
      callback(err); 
    } 
    else {
      console.log("Success:", data);
      callback(null, {
        id: params.Item.id.S,
        title: params.Item.title.S,
        watchHref: params.Item.watchHref.S,
        authorId: params.Item.authorId.S,
        length: params.Item.length.S,
        category: params.Item.category.S
      });
    }
  });
};