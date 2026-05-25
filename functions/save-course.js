const AWS = require("aws-sdk");
const dynamodb = new AWS.DynamoDB({ region: process.env.AWS_REGION, apiVersion: "2012-08-10" });

const replaceAll = (str, find, replace) => { 
  if (!str) return "";
  return str.replace(new RegExp(find, "g"), replace); 
};

exports.handler = (event, context, callback) => {
  const title = event.title || "default-title";
  const id = replaceAll(title, " ", "-").toLowerCase();
  
  const params = {
    Item: {
      id: { S: id },
      title: { S: title },
      watchHref: { S: `http://www.pluralsight.com/courses/${id}` },
      authorId: { S: event.authorId || "" },
      length: { S: event.length || "" },
      category: { S: event.category || "" }
    },
    TableName: process.env.TABLE_NAME
  };

  dynamodb.putItem(params, (err, data) => {
    if (err) { 
      console.log(err); 
      callback(err); 
    } 
    else {
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