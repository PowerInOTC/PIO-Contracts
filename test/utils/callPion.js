const axios = require('axios');

async function getResultList(asset1, asset2) {
  const requestBody = {
    app: "pionerV1_oracle",
    method: "price",
    params: {
      asset1: asset1,
      asset2: asset2
    }
  };

  try {
    const response = await axios.post('http://localhost:3000/v1/', requestBody, {
      headers: {
        'Content-Type': 'application/json'
      }
    });

    const data = response.data.result.data;
    console.log('Data within response.result.data:');
    console.log(JSON.stringify(data, null, 2));

    const resultList = [data.resultHash];
    data.signParams.forEach(param => {
      resultList.push(param.value);
    });

    return resultList;
  } catch (error) {
    console.error('Error:', error);
    return [];
  }
}

module.exports = {
    getResultList
};
